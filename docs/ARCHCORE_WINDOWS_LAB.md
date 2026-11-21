# Laboratorio de ArchCore en Windows

Estado al 21 de noviembre de 2026. **Compilación `release` para Windows x64 completada. `archcore.exe --help` terminó con código `0`.**

El objetivo del laboratorio es compilar ArchCore y obtener una salida correcta de `archcore.exe --help`. La revisión de ArchCore trabaja con EP8. Codemasters EP3 sigue siendo la referencia del proyecto principal. [Viabilidad del servidor EP3](EP3_SERVER_FEASIBILITY.md) · [Episodio de referencia de ArchCore](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-Episode.md)

## Entorno verificado

| Herramienta | Resultado de la auditoría |
| --- | --- |
| Windows | Windows 11 25H2, compilación `26200.9974`. El sistema y el proceso de PowerShell son x64. La compilación identifica Windows 11 aunque el campo histórico `ProductName` del registro diga `Windows 10 Home`. [Información de versiones de Windows 11](https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information) |
| Git | `2.51.0.windows.1`, disponible desde `C:\Program Files\Git\cmd\git.exe`. La ayuda local de `git clone` muestra `--revision`, `--filter` y `--no-checkout`. |
| Rustup, Rust y Cargo | Inicialmente ausentes. Se instalaron Rustup `1.29.3`, Rust `1.100.0` y Cargo `1.100.0`. `rustc -Vv` confirmó `x86_64-pc-windows-msvc`. |
| Visual Studio Build Tools y MSVC | Inicialmente ausentes. Se instalaron Build Tools 2022 `17.14.45`, el toolset `14.44.35207` y `cl.exe` y `link.exe` x64 `14.44.35230.0`. La instalación se comprobó con `vswhere` y los metadatos de ambos ejecutables. |
| Windows SDK | Inicialmente ausente. El SDK instalado es `10.0.26100.0`. Se comprobó la presencia de `kernel32.lib` y `ucrt.lib` para x64. |
| WinGet | `1.29.380`. El catálogo resolvió Rustup `1.29.3` desde `static.rust-lang.org` y Visual Studio Build Tools `17.14.45` desde `download.visualstudio.microsoft.com`. |
| Espacio | Aproximadamente 46,9 GiB disponibles en `C:` y 111,1 GiB en `D:` al comenzar la auditoría. |

Se comprobó que la rama local `develop` estaba limpia y coincidía con GitHub en `ba21cc7`. La rama de trabajo documental es `feature/archcore-windows-lab`.

## Procedencia y dependencias

- **Fuente.** GitHub devolvió el commit solicitado `ad280a6efc069526fc58445e5397d52a0e809500` del repositorio público `BlaMacfly/ArchCore`. GitHub no muestra una firma verificada para ese commit. El `README` declara GPL-3.0-or-later y `LICENSE` contiene el texto de la GPL v3. La declaración del código se evaluó por separado de los recursos del juego. [Commit](https://github.com/BlaMacfly/ArchCore/commit/ad280a6efc069526fc58445e5397d52a0e809500) · [Declaración del autor](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/README.md#license) · [Licencia](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/LICENSE)
- **Compilación.** Upstream indica `cargo build --release`. El manifiesto declara Rust 1.85 como mínimo. El perfil propuesto usa Rust estable para `x86_64-pc-windows-msvc`, Build Tools 2022 con MSVC x64/x86 y Windows SDK 26100. La versión efectiva de cada herramienta quedará registrada al compilar. [Guía de instalación](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-Installation.md#1-get-and-build-the-code) · [Cargo.toml](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/Cargo.toml) · [Rust para Windows MSVC](https://doc.rust-lang.org/rustc/platform-support/windows-msvc.html) · [Componentes de Build Tools 2022](https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2022)
- **Cargo.** El lockfile tiene 187 paquetes, incluidos los dos locales. Los 185 externos tienen checksum y la única fuente declarada es crates.io. El grafo filtrado para Windows x64 resolvió 156 paquetes y 31 scripts de compilación, incluido el de ArchCore. Se inspeccionaron sus entradas relevantes y las funciones activas en los scripts con detección de bibliotecas o comandos externos. `mysql_common` solo descarga fuentes de MySQL con una función de pruebas para Unix, inactiva en este grafo. `clang-sys` usa la función `runtime` y su script no busca libclang para enlazar en esta configuración. zlib y zstd usan las fuentes incluidas en sus crates para compilar con MSVC cuando no hay una biblioteca compatible preinstalada. [Cargo.lock](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/Cargo.lock)
- **SQL de compilación.** `build.rs` lee `sql/` y genera en `OUT_DIR` referencias a esquemas y migraciones que se embeben al compilar. La revisión de 62 archivos SQL o de compilación identificó definiciones de esquema, semillas de configuración y una migración que transforma filas existentes. No se identificó un volcado en los archivos inspeccionados. El árbol separado `data/server-ini` contiene, según el autor, tablas originales EP8 y queda fuera de la adquisición. [Script de compilación](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/build.rs) · [Origen de los datos EP8](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-Installation.md#4-import-the-client-data)
- **Alcance de `--help`.** El despacho de esa opción imprime el texto de uso y termina antes de la ruta que carga la configuración y conecta los servicios. Para este primer hito solo hacen falta el compilador, el código y sus dependencias de compilación. [Punto de entrada](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/main.rs#L41-L68)

## Procedimiento propuesto

### Instalación autorizada

Con `winget show` se comprobó la identidad y el origen de los paquetes. WinGet validó el SHA-256 de ambos instaladores. Build Tools añadió el compilador, enlazador y SDK al sistema. Rustup instaló la cadena estable para MSVC x64 en el perfil del usuario.

```powershell
winget show --exact --id Rustlang.Rustup --source winget
winget show --exact --id Microsoft.VisualStudio.2022.BuildTools --source winget
winget install --exact --id Microsoft.VisualStudio.2022.BuildTools --version 17.14.45 --source winget --override '--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.26100' --disable-interactivity
winget install --exact --id Rustlang.Rustup --version 1.29.3 --source winget --architecture x64 --override '-y --profile minimal --default-host x86_64-pc-windows-msvc --default-toolchain stable' --disable-interactivity
$rustup = 'C:\Users\josue\.cargo\bin\rustup.exe'
& $rustup --version
& $rustup toolchain list
& $rustup run stable-x86_64-pc-windows-msvc rustc -Vv
& $rustup run stable-x86_64-pc-windows-msvc cargo -V
```

Para repetir la prueba con el mismo compilador, usar `1.100.0-x86_64-pc-windows-msvc` en lugar de `stable-x86_64-pc-windows-msvc`. [Instalación oficial de Rust](https://rust-lang.org/install/) · [Parámetros de instalación de Visual Studio](https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2022)

### Obtención selectiva de fuentes

El checkout independiente está en `D:\proyectos\archcore-windows-lab`. El servidor Git de ArchCore anunció `filter` en el protocolo v2. Se comprobó que el clon no contenía blobs antes del checkout y, después, que los 245 blobs presentes correspondían a los 247 archivos permitidos. El conjunto excluye `data/`, `content/`, `db/` y `config/`. [Clonación parcial con Git](https://git-scm.com/docs/git-clone) · [Checkout disperso](https://git-scm.com/docs/git-sparse-checkout)

```powershell
$lab = 'D:\proyectos\archcore-windows-lab'
$revision = 'ad280a6efc069526fc58445e5397d52a0e809500'
git -c protocol.version=2 clone --revision=$revision --depth=1 --filter=blob:none --no-checkout --no-tags --no-recurse-submodules https://github.com/BlaMacfly/ArchCore.git $lab
git -C $lab rev-parse HEAD
git -C $lab config --get remote.origin.partialclonefilter
git -c core.hooksPath=NUL -C $lab sparse-checkout set --no-cone '/.gitattributes' '/Cargo.toml' '/Cargo.lock' '/LICENSE' '/crates/archcore/' '/crates/archcore-net/' '/sql/'
git -c core.hooksPath=NUL -C $lab checkout --detach $revision
git -C $lab hash-object Cargo.lock
git -C $lab status --short
```

El checkout quedó limpio en la revisión fijada. La huella Git de `Cargo.lock` es `65a1a6a46b8e82644d6d2a0aa9ed3d85ca06af5f` y coincide con el upstream.

### Compilación y verificación

Cargo obtuvo las dependencias del lockfile desde crates.io y escribió los paquetes en su caché de usuario. Se comprobó el grafo y se compiló sin conexión. Los artefactos quedan bajo `target/` del laboratorio. La única ejecución del binario fue con `--help`.

```powershell
Set-Location -LiteralPath 'D:\proyectos\archcore-windows-lab'
$rustup = 'C:\Users\josue\.cargo\bin\rustup.exe'
& $rustup run stable-x86_64-pc-windows-msvc cargo fetch --locked --target x86_64-pc-windows-msvc
& $rustup run stable-x86_64-pc-windows-msvc cargo metadata --locked --offline --format-version 1 --filter-platform x86_64-pc-windows-msvc
# Revisar el grafo y los scripts de compilación antes de continuar.
& $rustup run stable-x86_64-pc-windows-msvc cargo build --offline --locked --release -p archcore --target x86_64-pc-windows-msvc
$exe = 'target\x86_64-pc-windows-msvc\release\archcore.exe'
Get-Item -LiteralPath $exe
Get-FileHash -LiteralPath $exe -Algorithm SHA256
& $exe --help
$LASTEXITCODE
```

El hito se dará por completado si Cargo termina con código `0`, el ejecutable está presente, `--help` muestra el uso y termina con código `0`, y `Cargo.lock` sigue intacto. Registrar la huella SHA-256 del binario y las versiones de Rust, MSVC y SDK.

## Resultado y siguiente paso

| Verificación | Resultado real |
| --- | --- |
| Auditoría, procedencia y filtro de objetos | Completados. La revisión pública coincide con el SHA fijado y se delimitó el checkout. |
| Checkout | Completado en el directorio separado, con la revisión y la lista de objetos verificados. |
| Instalación | Completada. WinGet informó de éxito en ambos paquetes y se comprobaron MSVC, SDK, rustc y Cargo. |
| Compilación | Cargo terminó con código `0` en unos 2 min 36 s. Se comprobó que `Cargo.lock` siguió intacto. |
| Ejecutable | `D:\proyectos\archcore-windows-lab\target\x86_64-pc-windows-msvc\release\archcore.exe`. Cabecera PE x64 (`0x8664`), 21 723 648 bytes, SHA-256 `9ac727009c2d558c0c82dff247cb7a51acf9ec85c628efe6c006d2a6ac7ebbc9`. |
| Ayuda | Se ejecutó `archcore.exe --help`. Mostró la línea de uso y terminó con código `0`. |

```text
usage : archcore [login|world|all] | config | db-init | db-check | import | content | export-client-tables | migrate-ep8 | decrypt | i18n | sim | re (voir le wiki, page Outils)
```

### Incidencias

La primera consulta de WinGet falló dentro del aislamiento de la sesión. Fuera del aislamiento, WinGet respondió correctamente. Una consulta del catálogo informó de un fallo al refrescar el índice, pero devolvió los metadatos. WinGet verificó después los hashes de ambos instaladores y completó las instalaciones. Cargo compiló en el primer intento. Git rechazó la verificación del checkout desde la cuenta aislada por pertenecer a otra cuenta. La verificación desde la cuenta propietaria confirmó que sus archivos versionados siguen intactos.

### Próxima prueba

Una fase posterior puede comprobar una inicialización limpia de MariaDB y las escuchas en bucle local, con autorización para arrancar servicios. Esta entrega verifica la compilación y la ayuda de ArchCore en Windows. Quedan pendientes el arranque, el uso de datos del juego y la compatibilidad con Codemasters EP3.
