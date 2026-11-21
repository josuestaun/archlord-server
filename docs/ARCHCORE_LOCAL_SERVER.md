# Laboratorio local de ArchCore con MariaDB en Windows

## Alcance

ArchCore `ad280a6efc069526fc58445e5397d52a0e809500` es un laboratorio EP8. El objetivo de esta prueba es arrancar login y mundo con el esquema vacío en Windows x64 y comprobar sus sockets TCP en bucle local. El proyecto clásico mantiene Codemasters EP3 como referencia. [Viabilidad de EP3](EP3_SERVER_FEASIBILITY.md)

## Entorno y arquitectura

El binario x64 se compiló en Windows 11 25H2 con Rust y Cargo `1.100.0`, MSVC y Windows SDK `10.0.26100.0`. Se volvió a comprobar su SHA-256 antes de arrancar. El checkout y el ejecutable están en `D:\proyectos\archcore-windows-lab`. Su subdirectorio `local-server` contiene MariaDB, su directorio de datos, la configuración de ArchCore y los logs. Se restringió el acceso al directorio al usuario de Windows del laboratorio. [Compilación y huella del binario](ARCHCORE_WINDOWS_LAB.md)

| Componente | Escucha verificada | Función |
| --- | --- | --- |
| MariaDB | `127.0.0.1:3317/TCP` | Persistencia en cuatro esquemas de una instancia nueva. |
| Login | `127.0.0.1:11002/TCP` | Inicio de sesión y lista de mundos. |
| Mundo | `127.0.0.1:11008/TCP` | Servicio de juego. El mundo anuncia `127.0.0.1:11008`. |
| SOAP | Desactivado | Interfaz opcional de administración. |

`archcore.exe all` activa login y mundo en un solo proceso. El arranque comprueba la versión de los cuatro esquemas, carga las plantillas y registra la dirección anunciada del mundo antes de abrir login. Mundo abre su puerto después de cargar sus catálogos. Ambos servicios usan el protocolo de paquetes de ArchCore sobre TCP. [Secuencia de arranque](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/server.rs) · [Transporte](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/net.rs)

## MariaDB y migraciones

La guía de ArchCore indica MariaDB 10.6 o posterior. Se usó MariaDB `11.4.14` x64 de la serie LTS, distribuido como ZIP. La copia descargada de `mariadb-11.4.14-winx64.zip` coincidió con el SHA-256 oficial `9d9b410eb7b65f6616f29d933d76ee90cf7af4ba179a2d437e0f09f5bf6650df` antes de extraerla. [Guía de ArchCore](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-Installation.md) · [Versiones de MariaDB](https://mariadb.org/mariadb/all-releases/) · [Sumas del archivo oficial](https://archive.mariadb.org/mariadb-11.4.14/winx64-packages/sha256sums.txt)

| Esquema | SQL de referencia | Migraciones aplicadas | Última migración |
| --- | --- | ---: | --- |
| `archcore_auth` | `001_auth.sql` | 3 | `202611012100_retour_a_la_selection` |
| `archcore_characters` | `002_characters.sql` | 27 | `202611021800_objets_a_duree` |
| `archcore_world` | `003_world.sql`, `004_locale.sql` | 22 | `202611101000_source_des_traductions` |
| `archcore_logs` | Sus tablas se crean mediante sus migraciones. | 3 | `202610291000_anomalies` |

`db-init` ejecuta el SQL embebido en el binario. Las cuatro tablas `schema_migrations` sumaron 59 entradas, correspondientes a 55 migraciones y cuatro referencias `0000_reference`. El SQL de referencia incluye semillas de grupo, mundo e idiomas. Una migración copia sanciones de cuentas existentes dentro del esquema de autenticación. La instancia empezó vacía y se ejecutó `db-init` sin `--account`. [SQL](https://github.com/BlaMacfly/ArchCore/tree/ad280a6efc069526fc58445e5397d52a0e809500/sql) · [Inicializador de ArchCore](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/tools/db_init.rs) · [Verificación de migraciones](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/migrations.rs)

## Preparación de una instancia nueva

1. Comprobar el hash del ZIP y extraerlo bajo `local-server\distribution`. Crear un directorio de datos nuevo con `mariadb-install-db.exe --datadir=<ruta> --skip-networking`, sin registrar un servicio de Windows. Antes del primer arranque por TCP, alimentar por entrada estándar `mariadbd.exe --defaults-file=<ruta> --bootstrap --skip-networking` con la actualización de las cuentas `root` de la instancia nueva. La actualización sigue el formato del inicializador para `mysql.global_priv`, establece `mysql_native_password` y conserva solo esa autenticación. La prueba generó tres secretos independientes con 32 bytes aleatorios cada uno. Se suministraron hashes por entrada estándar y se guardaron las credenciales en archivos con ACL privada, sin pasar los secretos como argumentos. [Inicialización oficial de MariaDB en Windows](https://mariadb.com/docs/server/server-management/install-and-upgrade-mariadb/installing-mariadb/installing-system-tables-mariadb-install-db/mariadb-install-db-exe) · [Código del inicializador](https://github.com/MariaDB/server/blob/mariadb-11.4.14/sql/mysql_install_db.cc)
2. Crear `mariadb.ini` con la sección `[mariadbd]` y las rutas `basedir` y `datadir` de esta instancia. Establecer `bind-address=127.0.0.1`, `port=3317`, `skip-name-resolve`, `skip-log-bin`, `general-log=0`, `event-scheduler=OFF`, `local-infile=0` y `log-error` bajo `logs`. Usar `--defaults-file` como primera opción para que el servidor lea este archivo. Las opciones de cliente se guardan en archivos privados separados con `[client]`, `protocol=tcp`, `host=127.0.0.1`, `port=3317`, `user` y `password`. [Archivos de opciones de MariaDB](https://mariadb.com/docs/server/server-management/install-and-upgrade-mariadb/configuring-mariadb/configuring-mariadb-with-option-files)
3. Arrancar MariaDB y confirmar el PID, la escucha y una consulta SQL autenticada. Crear `archcore_migrator` y `archcore_runtime` limitados a `127.0.0.1`. Conceder al primero `SELECT`, `INSERT`, `UPDATE`, `CREATE`, `ALTER`, `INDEX` y `REFERENCES` sobre cada uno de los cuatro esquemas. Escapar el guion bajo con `\_` en los patrones de los `GRANT` de esquema. Ejecutar `archcore.exe db-init` con `ARCHCORE_DATABASE_USER` y `ARCHCORE_DATABASE_PASSWORD` configurados para el migrador solo en el proceso de inicialización. Retirar esas variables y bloquear la cuenta con `ALTER USER 'archcore_migrator'@'127.0.0.1' ACCOUNT LOCK`.
4. Conceder a `archcore_runtime` únicamente `SELECT`, `INSERT` y `UPDATE` en autenticación, esos tres permisos y `DELETE` en personajes, `SELECT` en mundo y `SELECT` e `INSERT` en logs. Esta cuenta usa `auth.conf` y `world.conf` con los mismos valores `Database.Host`, `Database.Port`, `Database.User`, `Database.Password`, `Database.Auth`, `Database.Characters`, `Database.World` y `Database.Logs`. Se usó `Database.ConnectionLimit = 4` en ambos archivos.
5. Fijar `LoginServer.Bind = "127.0.0.1"` y `LoginServer.Port = 11002` en `auth.conf`. Fijar `WorldServer.Bind = "127.0.0.1"`, `WorldServer.Port = 11008`, `WorldServer.PublicAddress = "127.0.0.1"`, `SOAP.Enabled = 0`, `SOAP.IP = "127.0.0.1"` y `Client.TablesDir = ""` en `world.conf`. ArchCore permite sobrescribir la configuración por entorno. Comprobar que ninguna variable heredada sustituya los ajustes de red o de base de datos. [Lector de configuración](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/config.rs)

## Arranque y parada

Desde una consola PowerShell propia para MariaDB, arrancar la instancia ya preparada en primer plano.

```powershell
$lab = 'D:\proyectos\archcore-windows-lab\local-server'
$bin = Join-Path $lab 'distribution\mariadb-11.4.14-winx64\bin'
& "$bin\mariadbd.exe" "--defaults-file=$lab\mariadb.ini" --console
```

Desde otra consola, comprobar el esquema y ejecutar ArchCore. Mantener esta consola disponible para pulsar Ctrl+C al terminar.

```powershell
$lab = 'D:\proyectos\archcore-windows-lab\local-server'
$env:ARCHCORE_ROOT = $lab
$env:ARCHCORE_CONF_DIR = Join-Path $lab 'archcore-config'
$archcore = 'D:\proyectos\archcore-windows-lab\target\x86_64-pc-windows-msvc\release\archcore.exe'
& $archcore db-check
if ($LASTEXITCODE -ne 0) { throw 'ArchCore schema check failed' }
& $archcore all
```

La prueba automatizada verificó los PID, los sockets TCP y UDP y la dirección anunciada por mundo. Las conexiones de prueba a login y mundo usaron `TcpClient` y se cerraron sin enviar paquetes del juego. Después de que ArchCore registre `arrêt…` y termine, apagar MariaDB desde la segunda consola y comprobar los puertos en escucha.

```powershell
$bin = Join-Path $lab 'distribution\mariadb-11.4.14-winx64\bin'
& "$bin\mariadb-admin.exe" "--defaults-file=$lab\private\admin.ini" shutdown
Get-NetTCPConnection -State Listen | Where-Object LocalPort -in 3317,11002,11008,7878
Get-Process -Name archcore,mariadbd,mysqld -ErrorAction SilentlyContinue
```

## Resultados y limitaciones

| Verificación | Resultado del 21 de noviembre de 2026 |
| --- | --- |
| MariaDB | `mariadbd --version` informó `11.4.14-MariaDB` para Win64 AMD64. La consulta por TCP autenticó a `root@127.0.0.1` y a `archcore_runtime@127.0.0.1`, confirmó la dirección y el puerto y comprobó que no había cuentas anónimas ni cuentas `root` sin contraseña. La cuenta de ejecución recibió el error esperado `1142` al intentar leer `mysql.global_priv`. |
| Esquema | `db-init` y `db-check` devolvieron `0`. Se comprobaron las 59 entradas y la coherencia de los cuatro esquemas. Las tablas de cuentas, personajes y segmentos del mapa estaban vacías. |
| ArchCore | `all` arrancó dos veces. Los logs confirmaron las conexiones a los cuatro esquemas y la escucha de login y mundo. El mundo anunció `127.0.0.1:11008`. |
| Red | Los tres sockets TCP pertenecían a los PID de MariaDB y ArchCore y usaban `127.0.0.1`. Los ocho sockets TCP establecidos observados también eran de bucle local. No se detectaron endpoints UDP de esos PID. Las dos conexiones TCP de prueba funcionaron. |
| Parada | En la repetición, ArchCore registró `arrêt…` y terminó con `0`. MariaDB devolvió `0` y registró `Shutdown complete`. Una sesión de PowerShell independiente confirmó que no quedaban procesos, escuchas en los puertos del laboratorio ni servicios de Windows registrados para ambos programas. |

La descarga directa agotó el tiempo de espera. Se completó mediante reanudación HTTPS en el espejo seleccionado por la API oficial de MariaDB y se verificó el hash del ZIP completo. En la primera ejecución en segundo plano ArchCore no respondió al Ctrl+C y se terminó únicamente su proceso. En la repetición se habilitó el manejo de Ctrl+C en el proceso padre antes de lanzar ArchCore. Ese atributo se hereda en Windows. El controlador de pruebas perdió su búfer de consola al desasociarse tras la parada, por lo que la inspección final se hizo desde otra sesión. [API oficial de descarga](https://downloads.mariadb.org/rest-api/mariadb/11.4.14/) · [Manejo de Ctrl+C en Windows](https://learn.microsoft.com/en-us/windows/console/setconsolectrlhandler)

ArchCore registró 92 avisos por claves de configuración omitidas y cinco por datos ausentes de conversión, refinado, gacha y tienda. Los contadores del mundo mostraron cero plantillas, sectores, PNJ y monstruos. La prueba cubrió el arranque y el transporte TCP. La autenticación de juego, los personajes y la entrada al mundo siguen pendientes. Para una prueba posterior, identificar una compilación autorizada de Archonia x64 EP8 o evaluar el modo sin interfaz de ArchRust, comprobar los datos mínimos de plantillas y mapa y preparar una cuenta ficticia. El simulador integrado podría servir para probar el protocolo con datos propios si se confirma que admite ese escenario. [Viabilidad de EP3 y opciones de cliente](EP3_SERVER_FEASIBILITY.md) · [Carga del mapa](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/world/map.rs) · [Importación de datos según ArchCore](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-Installation.md#4-import-the-client-data)
