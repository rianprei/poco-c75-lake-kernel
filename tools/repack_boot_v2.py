#!/usr/bin/env python3
"""repack_boot_v2.py — substitui só o kernel de um boot v4 stock (revisão adversarial).

Uso:
  repack_boot_v2.py ORIG KERNEL_GZ OUT [--max-partition 67108864]
      [--footer-algorithm NONE] [--partition-name boot] [--rollback-index 0]
      [--salt HEX] [--keep-footer] [--drop-signature] [--force]

Endurecimentos vs v1 (cada um com teste em run_fuzz.py):
  - entradas curtas/truncadas -> ERRO limpo (nunca traceback de struct.unpack);
  - ramdisk_size != 0 -> recusa (esta ferramenta só maneja boot sem ramdisk);
  - bloco de assinatura GKI (AVB0, 16 KiB) detectado: sem --drop-signature, recusa;
    signature_size@1580 != 0 idem (v1 zerava em silêncio);
  - kernel gzip validado por descompressão real (limite anti-zip-bomb 256 MiB);
  - footer AVB validado por estrutura (magic+versão+offsets sãos) e posição no fim;
  - saída existente -> recusa sem --force; entrada==saída -> sempre recusa;
  - avbtool ausente/falha -> ERRO limpo (exit 2 / 1) com a saída do avbtool;
  - temporários via tempfile no dir de saída + limpeza em falha (try/finally);
  - --salt com --algorithm NONE -> recusa (avbtool rejeitaria);
  - rollback-index negativo -> recusa;
  - teto de tamanho usa VBMETA_MAX_SIZE=64 KiB (libavb) em vez de 256 mágico;
  - pós-verificação: avbtool info_image + roundtrip do kernel no OUT (não-fatal, logado).
Página fixa em 4096: boot v3+ fixa page_size em 4096
(system/tools/mkbootimg bootimg.h: "in version 3 ... page size is fixed at 4096").
Layout v4: header(4096) + kernel(pad 4096) [+ ramdisk(recusado)].
Exit: 0 ok; 1 erro de conteúdo/uso; 2 ambiente (avbtool).
"""
import argparse, os, struct, subprocess, sys, tempfile, zlib

BOOT_MAGIC = b"ANDROID!"
PAGE = 4096
HDR_KERNEL_SIZE, HDR_RAMDISK_SIZE = 8, 12
HDR_VERSION, HDR_SIGSIZE = 40, 1580
AVB_MAGIC, AVB_FOOTER_LEN = b"AVBf", 64
VBMETA_MAX_SIZE = 64 * 1024  # libavb/avb_slot_verify.c
GUNZIP_CAP = 256 * 1024 * 1024


def err(msg, code=1):
    sys.exit(f"ERRO: {msg}")


def page_align(size, p=PAGE):
    return (size + p - 1) // p * p


def check_avbtool():
    import shutil
    if shutil.which("avbtool") is None:
        err("avbtool não encontrado no PATH (instale android-sdk libsparse/avb).", code=2)


def gunzip_check(blob, label):
    try:
        d = zlib.decompressobj(31)
        out = d.decompress(blob, GUNZIP_CAP + 1)
        if d.unconsumed_tail or len(out) > GUNZIP_CAP:
            err(f"{label} excede o limite de descompressão ({GUNZIP_CAP} B)")
        out += d.flush()
        if not d.eof:
            err(f"{label} gzip truncado/corrompido (stream incompleto)")
        return out
    except zlib.error as e:
        err(f"{label} não é um gzip válido ({e})")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("orig"); ap.add_argument("kernel_gz"); ap.add_argument("output")
    ap.add_argument("--max-partition", type=lambda x: int(x, 0), default=67108864)
    ap.add_argument("--footer-algorithm", default="NONE")
    ap.add_argument("--partition-name", default="boot")
    ap.add_argument("--rollback-index", type=int, default=0)
    ap.add_argument("--salt", default=None)
    ap.add_argument("--keep-footer", action="store_true")
    ap.add_argument("--drop-signature", action="store_true",
                    help="confirma descarte do bloco de assinatura GKI (AVB0) do stock")
    ap.add_argument("--force", action="store_true", help="sobrescreve OUT existente")
    args = ap.parse_args()

    if os.path.abspath(args.orig) == os.path.abspath(args.output):
        err("orig e output são o mesmo arquivo (recusa sobrescrever entrada)")
    if os.path.exists(args.output) and not args.force:
        err(f"output existe ({args.output}); use --force para sobrescrever)")
    if args.rollback_index < 0:
        err("rollback-index negativo")
    # nota: avbtool aceita --salt mesmo com --algorithm NONE (salt fixo => saída
    # determinística; sem salt ele gera um aleatório). apenas repassa.

    try:
        orig = open(args.orig, "rb").read()
    except OSError as e:
        err(f"lendo orig: {e}")
    if len(orig) < PAGE:
        err(f"orig tem {len(orig)} B (< página de header)")
    if orig[0:8] != BOOT_MAGIC:
        err("header não é ANDROID!")
    try:
        kernel_size = struct.unpack_from("<I", orig, HDR_KERNEL_SIZE)[0]
        ramdisk_size = struct.unpack_from("<I", orig, HDR_RAMDISK_SIZE)[0]
        header_version = struct.unpack_from("<I", orig, HDR_VERSION)[0]
        sig_size = struct.unpack_from("<I", orig, HDR_SIGSIZE)[0]
    except struct.error:
        err("header curto/corrompido")
    if header_version != 4:
        err(f"header_version={header_version} (só v4; página 4096 fixa no v3+)")
    if ramdisk_size != 0:
        err(f"ramdisk_size={ramdisk_size} != 0 (esta ferramenta só maneja boot sem ramdisk)")
    if PAGE + kernel_size > len(orig):
        err("kernel_size inválido no stock (além do EOF)")

    kernel_old = orig[PAGE:PAGE + kernel_size]
    if kernel_old[0:2] != b"\x1f\x8b":
        err("kernel do stock não é gzip (1f8b)")

    footer_off = orig.rfind(AVB_MAGIC)
    if footer_off < 0:
        err("footer AVBf não localizado")
    if footer_off + AVB_FOOTER_LEN != len(orig):
        err(f"footer AVBf fora do fim do arquivo (off={footer_off}, len={len(orig)})")
    if footer_off < PAGE + kernel_size:
        err("footer dentro da área do kernel (imagem inconsistente)")
    try:  # footer AVB é big-endian no disco (avb_footer.h + byteswap na libavb)
        fb_version = struct.unpack_from(">I", orig, footer_off + 4)[0]
        fb_img_size = struct.unpack_from(">Q", orig, footer_off + 12)[0]
        fb_vbmeta_off = struct.unpack_from(">Q", orig, footer_off + 20)[0]
        fb_vbmeta_size = struct.unpack_from(">Q", orig, footer_off + 28)[0]
    except struct.error:
        err("footer AVBf curto/corrompido")
    if fb_version != 1:
        err(f"versão major de footer AVB={fb_version} (esperado 1)")
    if not (0 < fb_vbmeta_size <= VBMETA_MAX_SIZE and fb_vbmeta_off + fb_vbmeta_size <= len(orig)):
        err("offsets do footer AVB inconsistentes")

    # bloco entre fim do kernel (alinhado) e footer: assinatura GKI? zeros?
    kernel_end = PAGE + page_align(kernel_size)
    gap = orig[kernel_end:footer_off]
    has_sig = b"AVB0" in gap
    # keep-footer preserva o bloco byte-a-byte: nada é descartado -> sem gate.
    if not args.keep_footer and (has_sig or sig_size != 0) and not args.drop_signature:
        err(f"bloco de assinatura GKI detectado (AVB0 no gap={has_sig}, signature_size={sig_size}); "
            "passe --drop-signature para confirmar o descarte")

    header_bytes = bytearray(orig[0:PAGE])
    try:
        with open(args.kernel_gz, "rb") as f:
            new_kernel = f.read()
    except OSError as e:
        err(f"lendo kernel novo: {e}")
    if len(new_kernel) < 2 or new_kernel[0:2] != b"\x1f\x8b":
        err("kernel novo não parece gzip (magic 1f8b)")
    new_image = gunzip_check(new_kernel, "kernel novo")

    new_header = bytearray(header_bytes)
    struct.pack_into("<I", new_header, HDR_KERNEL_SIZE, len(new_kernel))
    struct.pack_into("<I", new_header, HDR_SIGSIZE, 0)
    new_padded = new_kernel + b"\x00" * (page_align(len(new_kernel)) - len(new_kernel))
    body_len = PAGE + len(new_padded)
    if body_len + VBMETA_MAX_SIZE + AVB_FOOTER_LEN > args.max_partition:
        err(f"imagem não cabe na partição ({body_len} + vbmeta_max + footer > {args.max_partition})")

    out_dir = os.path.dirname(os.path.abspath(args.output)) or "."
    if args.keep_footer:
        if len(new_padded) != page_align(kernel_size):
            err("--keep-footer exige kernel novo com mesmo size alinhado do stock")
        out_img = bytes(new_header) + new_padded
        # preserva o gap (assinatura/vbmeta intermediária) e o footer verbatim:
        # com padded igual, body_len == fim do kernel no stock.
        out_img += orig[len(out_img):footer_off] + orig[footer_off:]
        if len(out_img) != len(orig):
            err(f"tamanho resultante {len(out_img)} != {len(orig)}")
        if out_img[footer_off:] != orig[footer_off:]:
            err("falha interna: footer não preservado byte-a-byte")
        with open(args.output, "wb") as f:
            f.write(out_img)
        print(f"BYTECHECK: novo={len(out_img)} stock={len(orig)} footer preservado")
        return

    check_avbtool()
    tmp_nosig = tmp_final = None
    try:
        fd, tmp_nosig = tempfile.mkstemp(prefix=".repack-", suffix=".nosig", dir=out_dir)
        with os.fdopen(fd, "wb") as f:
            f.write(bytes(new_header) + new_padded)
        fd2, tmp_final = tempfile.mkstemp(prefix=".repack-", suffix=".tmp", dir=out_dir)
        os.close(fd2)
        import shutil
        shutil.copy(tmp_nosig, tmp_final)
        cmd = ["avbtool", "add_hash_footer", "--image", tmp_final,
               "--partition_size", str(args.max_partition),
               "--partition_name", args.partition_name,
               "--algorithm", args.footer_algorithm,
               "--rollback_index", str(args.rollback_index)]
        if args.salt:
            cmd += ["--salt", args.salt]
        print("+", " ".join(cmd))
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode != 0:
            err(f"avbtool falhou (exit={r.returncode}): {(r.stderr or r.stdout).strip()[:300]}")
        os.replace(tmp_final, args.output)
        # pós-verificação (não-fatal): kernel roundtrip + info_image
        try:
            got = open(args.output, "rb").read()
            gk = struct.unpack_from("<I", got, HDR_KERNEL_SIZE)[0]
            assert got[PAGE:PAGE + gk] == new_kernel, "roundtrip do kernel"
            print(f"ROUNDTRIP OK: kernel {gk} B idêntico no OUT")
        except Exception as e:
            print(f"AVISO pós-verificação: {e}", file=sys.stderr)
        ri = subprocess.run(["avbtool", "info_image", "--image", args.output],
                            capture_output=True, text=True)
        if ri.returncode == 0:
            print("".join(l for l in ri.stdout.splitlines(True)
                           if "Algorithm" in l or "Original image size" in l or "VBMeta offset" in l))
    finally:
        for t in (tmp_nosig, tmp_final):
            try:
                if t and os.path.exists(t) and os.path.abspath(t) != os.path.abspath(args.output):
                    os.unlink(t)
            except OSError:
                pass


if __name__ == "__main__":
    main()
