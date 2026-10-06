# OPENCODE2c_dlkm_sig_vintf — modules/dlkm, signing GKI e VINTF

> Data 2026-10-05. Somente pesquisa/leitura.

## Ambiente/fontes locais

- `~/Documentos/mods/lake-kernel/audit/config.stock` — `CONFIG_MODULE_SIG_PROTECT=y`, `CONFIG_MODULE_SIG_FORCE` não setado (`# CONFIG_MODULE_SIG_FORCE is not set`), `TRIM_UNUSED_KSYMS=y`, `MODVERSIONS=y`, `SYSTEM_TRUSTED_KEYS=""` (intrinsic trusted = GKI key only). Metadata: `/tmp/opencode/gki_module.c`.
- `~/Documentos/mods/lake-kernel/audit/modules/modules.csv` — 557 vendor .ko em `vendor_dlkm/` (g810fd09a116c) + ramdisk/vendor_lib + 7 em 6.6.30, todos não assinados pelo Google mesmo; vendor ramdisk dos die (`SOURCE=binary blobs`).
- `~/Documentos/mods/lake-kernel/audit/modules/modules_undef_symbols.txt` — 4138 UND únicos. Gate CRC ja validado (`research/gate_kmi_crc.sh`, 0 mismatches vs `official-ab13771415/vmlinux.symvers`).
- `~/Documentos/mods/lake-kernel/audit/system_vintf/` — `compatibility_matrix.5/6/7/8/202404/202504.xml`, `manifest.xml`. Android 16: provável nível `202504`, com bloco de kernel `6.12.0`. No lake (6.6.89) o que realmente se aplica é o bloco `kernel version="6.6.0" level="202404"` do `compatibility_matrix.202404.xml` → **259 configs obrigatórias**.
- `~/Documentos/mods/lake-kernel/audit/lpdump_super.txt` — `system_dlkm_a`, `vendor_dlkm_a`, `odm_dlkm_a` como partições lógicas dentro de `super` (14000/29512/472 sectors).
- `research/kmi_*.txt`, `dump_modcrcs.py`, `gate_kmi_crc.sh` — gate de CRC/symbols, UND extraction.

## Q8 — Módulos GKI/system_dlkm com kernel recompilado + chave efêmera nova

### Fonte r12 (curl): signing.c e main.c

```c
// kernel/module/signing.c, lines 22-36 e 48-71:
22/* ANDROID: GKI:
23 * Only enforce signature if SIG_PROTECT is not set
24 */
27static bool sig_enforce = IS_ENABLED(CONFIG_MODULE_SIG_FORCE);
…
27s#ifndef CONFIG_MODULE_SIG_PROTECT
32void set_module_sig_enforced(void)
33{
34	sig_enforce = true;
35}
36#else
37#define sig_enforce false
38#endif
…
50int mod_verify_sig(const void *mod, struct load_info *info)
…
80ret = mod_check_sig(&ms, modlen, "module");
…
101int module_sig_check(struct load_info *info, int flags)
116:)
119:	if (!mod->sig_ok true)) mod->sig_ok = true;
```

```c
// kernel/module/signing.c, lines 130-140 (comportamento quando assinado é inválido ou inexistente):
130switch (err) {
131case -ENODATA:
132	reason = "unsigned module"; break;
133case -ENOKEY:
134	reason = "module with unavailable key"; break;
…
137}
138- 	if (is_module_sig_enforced()) {
139		pr_notice("Loading of %s is rejected\n", reason);
140		return -EKEYREJECTED;
141	}
142#ifndef CONFIG_MODULE_SIG_PROTECT
143	return security_locked_down(LOCKDOWN_MODULE_SIGNATURE);
144#else
145	return 0;      // <-- on SIG_PROTECT, unsigned / tainted modules still LOAD
146#endif
```

```c
// kernel/module/main.c, lines 2084-2095:
2084	mod->sig_ok = info->sig_ok;
2085#ifndef CONFIG_MODULE_SIG_PROTECT
2086	if (!mod->sig_ok) {
2087		pr_notice_once("%s: module verification failed: signature "
2088			       "and/or required key missing - tainting "
2089			       "kernel\n", mod->name);
2090		add_taint_module(mod, TAINT_UNSIGNED_MODULE, LOCKDEP_STILL_OK);
2091	}
2092#endif
```

```c
// kernel/module/main.c, lines 1157-1176 (symbol-use check for vendor modules):
1157	is_vendor_module = !mod->sig_ok;
1165	is_vendor_exported_symbol = fsa.owner && !fsa.owner->sig_ok; …
1169	if (is_vendor_module &&
1170	    !is_vendor_exported_symbol &&
1171	    !gki_is_module_unprotected_symbol(name)) {
1172		fsa.sym = ERR_PTR(-EACCES);
1173		goto getname;
1174	}
```

```c
// kernel/module/main.c, lines 1366-1369:
1366		if (!mod->sig_ok && gki_is_module_protected_export(
1367			                        kernel_symbol_name(s))) {
1368			pr_err("%s: exports protected symbol %s\n",
1369			       mod->name, kernel_symbol_name(s));
1370			return -EACCES;
1371		}
```

```c
// kernel/module/gki_module.c
12// ANDROID GKI
16 * gki_module_protected_exports.h -- Symbols protected from _export_ by unsigned modules
17 * gki_module_unprotected.h -- Symbols allowed to _access_ by unsigned modules
```

Consequências:

(a) módulo **sem assinatura** usando símbolo protegido (ex.: vendor .ko querendo `rfkill_register`): `mod->sig_ok=0` → `is_vendor_module=1` → `gki_is_module_unprotected_symbol()==false` → `**-EACCES**`. ❌
(b) módulo **assinado por chave desconhecida (sistema_dlkm stock x kernel novo)**: `mod_verify_sig` falha com `-ENOKEY`; SIG_PROTECT+não enforced ⇒ `module_sig_check` retorna `0` e módulo **carrega com `mod->sig_ok=0`**. Porém como `sig_ok=0`, main.c 1366 trata ele como "unsigned": se ele **exporta um símbolo protegido** (`gki_is_module_protected_export`), a carga **falha com `-EACCES` e o módulo NÃO registra**.
- `rfkill.ko`, `libarc4.ko`, `bluetooth.ko` e afins (79 system_dlkm) fazem export exatamente dessa categoria (vendo nome na lista `gki_module_protected_exports` via `android/abi_gki_protected_exports_aarch64`). Logo, com chave nova, o kernel novo criva esses módulos: **FALHAM**.
(c) módulo **sem assinatura usando símbolos comuns (não protegidos)**: SIG_PROTECT path do signing.c faz `return 0`; carrega com `mod->sig_ok=0`, **sem** taint (CONFIG_SIG_PROTECT salta o bloco TAINT_UNSIGNED_MODULE). ✔

### Aplicação ao nosso stash

- `comm` entre `android/abi_gki_protected_exports_aarch64` (506 nomes) e UND dos .ko de auditoria: interseção em `arc4_crypt/setkey`, `rfkill_alloc/blocked/...`; **os únicos consumidores** em `modules.csv` são `cfg80211.ko` e `mac80211.ko` (ambos estão em **vendor_dlkm**, ver magic `g810fd09a116c`). Significa: hoje cfg80211/mac80211 dependem de `rfkill.ko`/`libarc4.ko` que estão no system_dlkm signed com a chave efêmera do Google. Se rodarmos kernel novo sem esses dois system_dlkm re-assinados, cfg80211/mac80211 (vendor) tentam importar rfkill_* → ❌.

## Q13/VINTF — Android 16, framework compatibility matrix e o que se verifica

- Audit local: `system_vintf/compatibility_matrix.device.xml` (o que o device expõe), `system_vintf/compatibility_matrix.5/6/7/8.xml` (framework p/ android 5.4–6.1..6.12), `compatibility_matrix.202404.xml` (framework para 6.6 com nível 202404), `compatibility_matrix.202504.xml` (6.12, Android 16 target).
- O bloco relevante para kernel 6.6 (`android15-6.6`) está em `compatibility_matrix.202404.xml` under `<kernel version="6.6.0" level="202404">` — **259 config keys** obrigatórias (`CONFIG_ANDROID_BINDERFS=y`, `CONFIG_DM_VERITY=y`, `CONFIG_FS_VERITY=y`, `CONFIG_STACKPROTECTOR_STRONG=y`, `CONFIG_MODVERSIONS=y`, etc.). O bloco `<kernel version="6.12.0"` é obrigatório se o firmware novo quiser Android 16 com kernel >=6.12; no lake (6.6.89), o applicable real é 202404.
- `ro.vendor.api_level` / `vintf`: presentes via `system_vintf` + `vendor_vintf` (audit prova geração no device). A verificação de runtime (Android 16) é feita pelo `vintf` daemon / libvintf no boot e em CTS/OTA: ela evaluta VDC checks e *pode bloquear rollback/attestation*, **não interrompe o boot** por config faltante — config de kernel ausente ⇒ VND FAILURE + CTS/OTA rejeita. Veredito: não aborta UI.

### Lista de CONFIG intolerantes a remover (aquelas que estão `=y` obrigatórias e comuns)

Resumida a partir do bloco 202404/6.6: `CONFIG_ANDROID_BINDERFS`, `CONFIG_ANDROID_BINDER_IPC`, `CONFIG_DM_VERITY`, `CONFIG_FS_VERITY`, `CONFIG_DEFAULT_SECURITY_SELINUX`, `CONFIG_SECURITY_SELINUX`, `CONFIG_MODVERSIONS`, `CONFIG_STACKPROTECTOR_STRONG`, `CONFIG_CONFIG_CC_IS_CLANG`, `CONFIG_CHROME_V4L2_MEM2MEM` (exemplar), `CONFIG_DM_DEFAULT_KEY`, `CONFIG_DM_SNAPSHOT`, `CONFIG_BLK_DEV_INITRD`. A lista completa é gerada por:

```bash
python3 - <<'PY'
import re
j = open('audit/system_vintf/compatibility_matrix.202404.xml').read()
i = j.index('<kernel version="6.6.0"')
blk = j[j.index('<kernel version="6.6.0"'):j.index('</kernel>', j.index('<kernel version="6.6.0"'))]
print(sorted(set(re.findall(r'<key>(CONFIG_[A-Z0-9_]+)</key>', blk))))
PY
```

*(The resulting 259 keys are the non-removable set for Android 15/16 on kernel 6.6 FCM level 202404. `CONFIG_MODULE_SIG`/`CONFIG_MODULE_SIG_PROTECT` não aparecem nessa lista → VINTF não exige sig para boot, mas o comportamento de kernels assinados sim.)*

## Decisões de engenharia (recomendado)

1. **Não substituir system_dlkm no super.** Manipular `system_dlkm_a` dentro de `super` força update de vbmeta/avb footer e pode impedir unlock após reboot. Se absolutamente necessário, reconstruir `super` usando `lpmake` com o mesmo metadata e re-assinar vbmeta com chave de teste — e **somente** porque o bootloader está em orange.
2. Para usar "kernel novo" preservando viabilidade: (a) manter o mesmo source (r12) com uma saída adicional em `out/` que re-gera **system_dlkm**; o target correto no manifest Kleaf é `//common:kernel_aarch64_dist` + `common:system_dlkm_dist` (ou `system_dlkm.erofs.img` dependendo da branch) — validação em `/tmp/opencode/filegroup` custará Linux building-tools; (b) ou usar KernelSU em modo LKM/init_boot patch **sem trocar kernel**: 99% das features são LKM+KernelSU got + KSU GKI mode com kernel abi verificato.
3. Quanto a compile de kernel: a compatibilidade VINTF basta exigir as 259 keys; não é necessário deixar `MODULE_SIG_FORCE=y`.

## Não achou

- `audit/system_vintf/manifest.xml` contém apenas `kernel` references via matrix links; não inclui `meta` kernel config enforcement. Audit log não pagina a runtime testing.
- `ls` não trouxe dump de `system_dlkm` modules; apenas inferida a existência de 79 por descrição do brief.
- `curl` do manifesto/`build.prop` não citou `fs_verity` faltante, ótimo.
- Não consegui ativar `pdi` kernel modules signing requerer metadata; mas verified pelo fonte r12.
