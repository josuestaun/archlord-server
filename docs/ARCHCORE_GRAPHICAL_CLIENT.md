# Cliente gráfico para el laboratorio ArchCore

Investigación iniciada el 21 de noviembre de 2026 y actualizada el 22 de noviembre de 2026. El servidor de referencia es ArchCore en `ad280a6efc069526fc58445e5397d52a0e809500`, con datos y protocolo de EP8 en Windows x64. El proyecto prioriza una primera versión jugable de EP8 con ArchCore y Archonia x64. Después se evaluarán las adaptaciones hacia Codemasters EP3 (2008–2009).

## Conclusión

El cliente comercial de referencia es **Archonia de 64 bits, `Game/Archonia.exe`**. El mantenedor de ArchCore documenta una prueba con ese ejecutable y sus datos el 25 de octubre de 2026, y registra login, personajes, entrada al mundo, NPC, movimiento y visibilidad como comprobados dentro del juego. La documentación fijada no identifica la compilación, el parche, el SHA-256 ni el instalador que usó. [Episodio y cliente de referencia](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-Episode.md#L4-L17) · [Comprobaciones del mantenedor](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-Episode.md#L53-L76)

El cliente del paquete oficial con parche `665` está extraído en `D:\proyectos\archonia-client-lab\client\Archonia`. En una prueba desechable se confirmó que el cliente gráfico puede iniciar sesión, seleccionar un Knight y entrar en el mundo de ArchCore. También se vieron el personaje y el terreno. Las condiciones públicas consultadas no aclaran el permiso para conectar el cliente a un servidor privado en loopback. **ArchRust queda como alternativa secundaria**, con su modo `--no-client` y recursos propios si hacen falta. [Resultado con elevación](#segundo-ensayo-gráfico-con-elevación-autorizada) · [Términos de Archonia](https://archonia.net/termsofuse?culture=en) · [Capacidades de ArchRust](https://github.com/BlaMacfly/ArchRust/blob/256888eb123063e21711bde98f9572c44fed5bee/README.en.md#L23-L49)

En la sesión persistente se creó un Knight desde el cliente, se entró al mundo y se vio al personaje entre una montaña y una roca. Al salir, ArchCore registró seis paquetes de movimiento y la posición horizontal seguía en el origen. El siguiente hito es comprobar un recorrido sobre terreno abierto y recuperar su posición al volver a entrar. [Sesión manual persistente](#sesión-manual-persistente-del-parche-665)

El primer intento del 22 de noviembre se detuvo al arrancar `Archonia.exe`. Windows devolvió el error `740` y no creó el proceso con la cuenta estándar utilizada. [Resultado del ensayo](#primer-ensayo-gráfico-del-parche-665)

## Protocolo y evidencias

- **Familia de protocolo.** El código sigue el dialecto de Archonia x64 sobre el juego Webzen EP8, «The Dark Revelation» (26 de septiembre de 2012). El transporte usa paquetes `AuPacket` sobre TCP. El saludo `AGPMSTARTUPENCRYPTION` (`0x48`) establece el cifrado Blowfish. El login `AGPMLOGIN` (`0x0D`) usa un desafío de contraseña con RC4 y devuelve la información del mundo. Para entrar, el cliente abre otra conexión y usa un token de sesión de un solo uso. La secuencia de entrada termina en `FINISH_ENTER`. La documentación enumera diferencias con Webzen en tamaños de campos y operaciones. Compartir episodio o arquitectura x64 es insuficiente para afirmar compatibilidad. [Protocolo fijado](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-Network-protocol.md#L25-L90) · [Flujo local de sesión](ARCHCORE_AUTHENTICATION_TEST.md)
- **Versión e integridad.** En las rutas de login y entrada inspeccionadas no se identificó una comprobación general de versión de compilación o hash del ejecutable. `ARCHCORE_EXT` (`0xAC`) tiene una especificación propia v1.2 y negocia capacidades de ArchRust. Entre ellas está la huella de las tablas exportadas por el servidor en `tables.toml`. Esa huella sirve para detectar datos ausentes o desactualizados y su valor no identifica una compilación de Archonia. [Código de login](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/login.rs) · [Extensiones y huella de tablas](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-ArchRust-extensions.md#L1-L25)
- **Demostrado en nuestro laboratorio.** Con el servidor fijado, `archcore sim client` autenticó, creó el Knight TID `96` con CID `1`, recuperó el mismo personaje tras reconectar y recibió `FINISH_ENTER` dos veces. Una conexión TCP confirma únicamente que hay un servicio escuchando. Los mensajes de sesión, la fila de MariaDB y `FINISH_ENTER` respaldan el flujo sin interfaz. Aún falta validarlo con un cliente gráfico. [Prueba local de creación y entrada](ARCHCORE_CHARACTER_CREATION.md)
- **Pareja ArchRust–ArchCore.** La revisión candidata `256888eb123063e21711bde98f9572c44fed5bee` es del 19 de noviembre de 2026. Su `Cargo.lock` fija `archcore-net` en `ba4750d0ef55f0a2abeb0e9dfb2e7fd788b7b445`. GitHub sitúa nuestro servidor 83 commits por delante de esa revisión y la comparación incluye cambios en `packet.rs` y `schema.rs`. Las pruebas gráficas upstream hacen de ArchRust un candidato con evidencia. La compatibilidad de estos dos pines requiere una prueba real que use el lockfile. [Dependencia fijada](https://github.com/BlaMacfly/ArchRust/blob/256888eb123063e21711bde98f9572c44fed5bee/Cargo.lock#L204-L215) · [Comparación de ArchCore](https://github.com/BlaMacfly/ArchCore/compare/ba4750d0ef55f0a2abeb0e9dfb2e7fd788b7b445...ad280a6efc069526fc58445e5397d52a0e809500)

## Clientes y procedencia

| Candidato | Evidencia de compatibilidad | Procedencia y dificultad |
| --- | --- | --- |
| Archonia x64, `Archonia.exe` | Build del mantenedor sin identificar. Con nuestro parche `665` y el pin de ArchCore se confirmaron la autenticación y la entrada al mundo desde la GUI. | El artefacto se obtuvo del canal oficial. Queda pendiente aclarar las condiciones del operador para el uso local. [Página de descargas del operador](https://archonia.net/download?culture=en) |
| ArchRust `256888e` | Upstream reporta creación, entrada, terreno y movimiento. El par de pines y el flujo completo con recursos propios están pendientes. | [Código fijado](https://github.com/BlaMacfly/ArchRust/tree/256888eb123063e21711bde98f9572c44fed5bee) · [Licencia GPL-3.0 o posterior](https://github.com/BlaMacfly/ArchRust/blob/256888eb123063e21711bde98f9572c44fed5bee/LICENSE.md). No se encontró un binario publicado para ese pin en [Releases](https://github.com/BlaMacfly/ArchRust/releases). Esfuerzo medio para revisar dependencias, compilar en Windows y probar el modo gráfico. |
| Cliente original de Webzen EP8 | Compatible como referencia documental de ciertos datos. Compatibilidad de red y del ejecutable sin verificar, con diferencias de paquetes documentadas. | No se identificó una distribución autorizada que además esté comprobada con este ArchCore. Esfuerzo alto de verificación y eventual adaptación. [Protocolo y diferencias](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-Network-protocol.md#L25-L45) |
| Cliente Codemasters EP3 | Sin evidencia con esta revisión. | Esfuerzo alto. Requiere identificar por separado una revisión de EP3 y su protocolo. [Investigación clásica](CLASSIC_SERVER_RESEARCH.md) |
| Visor o cliente gráfico propio | Viable como proyecto de ingeniería sobre el protocolo documentado. Sin implementación ni prueba local. | Esfuerzo medio-alto para un visor con controles básicos y geometría propia. Esfuerzo alto para un cliente con interfaz, animaciones, mapas y jugabilidad. [Biblioteca de protocolo](https://github.com/BlaMacfly/ArchCore/tree/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore-net) |

## Permiso y versión necesarios para iniciar la prueba

- Los términos públicos describen el uso personal del sitio y reservan los derechos sobre sus materiales. Las reglas de juego se aplican al servicio de Archonia. En las fuentes públicas consultadas no se encontró una licencia del cliente que aclare el uso con un servidor particular en `127.0.0.1`, ni el uso de los datos de personaje y terreno en nuestro servidor. La página de descarga ofrece un instalador y un paquete, sin identificar cuál corresponde a la prueba del mantenedor. [Términos del sitio](https://archonia.net/termsofuse?culture=en) · [Reglas del servicio](https://archonia.net/guide/rules/in-game-rules/english) · [Descarga oficial](https://archonia.net/download?culture=en)
- Las notas del parche 535–536 del 29 de mayo de 2026 mencionan una etiqueta «Local» para cuentas de EasyLogin. La nota describe la presentación de las cuentas y deja sin aclarar si el launcher dirige a un servidor de terceros o si está permitido hacerlo. [Notas de Archonia sobre EasyLogin](https://archonia.net/news/163/patch%20535-536?culture=es)
- Pedir al mantenedor el nombre exacto del paquete x64, fecha, versión o parche y SHA-256 del ejecutable y del paquete que usó el 25 de octubre de 2026. Pedir al operador o titular correspondiente confirmación escrita de que permite usar ese cliente y sus recursos para una prueba privada de ArchCore en loopback, además del enlace verificable y del método de arranque soportado. Aclarar por separado si se pueden usar datos del juego en el lado servidor, por ejemplo para generar las alturas de la zona. No se contactó a terceros durante esta tarea. [Prueba del mantenedor](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-Episode.md#L53-L76) · [Soporte oficial de Archonia](https://archonia.net/support)

## Instalador oficial descargado

El 21 de noviembre de 2026 se descargó `ArchoniaSetup.exe` mediante la opción **Direct Installer** de la página de Archonia, operada por Altay Games. La descarga usó HTTPS, desde `archonia.net/ArchoniaSetup.exe`, sin redirecciones ni mirrors. El enlace directo no solicitó iniciar sesión ni aceptar condiciones adicionales. Las condiciones que pueda mostrar el instalador siguen pendientes de revisión. [Página oficial de descarga](https://archonia.net/download?culture=en) · [Operador y términos](https://archonia.net/termsofuse?culture=en)

| Dato | Resultado |
| --- | --- |
| Ubicación | `D:\proyectos\archonia-client-lab\ArchoniaSetup.exe`, fuera del repositorio Git |
| Tamaño | `144999986` bytes, aproximadamente 138,3 MiB. Coincide con el encabezado HTTP `Content-Length`. La página todavía indica 112 MB. |
| SHA-256 | `f97ae2e63475f8129803c0bbe8cf7b5fba7cd3261cf70ca88e6980e220deda27`. Coincidieron `Get-FileHash` y `certutil`. |
| Versión y arquitectura | `FileVersion` y `ProductVersion` `2026.11.19.2`. Cabecera PE x64, identificador `0x8664`. `OriginalFilename` indica `Archonia Launcher.dll`. Estos metadatos corresponden al instalador. La versión de `Game\Archonia.exe` se registra en la sección del paquete directo. |
| Firma y procedencia | Windows informó `NotSigned` en `Get-AuthenticodeSignature`. Se conservó la marca de origen de Internet (`Zone.Identifier`, zona 3). No se encontró un SHA-256 publicado por el operador para comparar con el cálculo local. |

La descarga directa acredita de dónde se obtuvo esta copia. La firma ausente y la falta de un hash publicado impiden verificar criptográficamente la identidad del editor o comparar con el build que se probó con ArchCore. Antes de la instalación conviene solicitar el hash al operador y confirmar si espera que el instalador aparezca sin firma. [Soporte oficial de Archonia](https://archonia.net/support)

## Comprobación previa a la instalación

- **Integridad local.** Se recalculó el SHA-256 y coincidió con el registrado. Se confirmó la versión `2026.11.19.2`, el estado Authenticode `NotSigned` y la marca de origen de Internet.
- **Microsoft Defender.** El 21 de noviembre de 2026, con protección en tiempo real activa y firmas `1.463.403.0`, se ejecutó `Start-MpScan -ScanType CustomScan -ScanPath 'D:\proyectos\archonia-client-lab\ArchoniaSetup.exe'`. Los eventos `1000` y `1001` del mismo identificador confirmaron que el análisis comenzó y terminó. El historial de Defender no registró amenazas para el instalador. [Comando de análisis](https://learn.microsoft.com/en-us/powershell/module/defender/start-mpscan) · [Eventos de Defender](https://learn.microsoft.com/en-us/defender-endpoint/troubleshoot-microsoft-defender-antivirus)
- **Punto de entrada y elevación.** Se leyeron como datos el recurso `RT_MANIFEST` del PE y el manifiesto del paquete .NET. El valor efectivo de `requestedExecutionLevel` es `requireAdministrator`. El ejecutable arranca `Archonia Launcher.dll` e incluye los runtimes `Microsoft.NETCore.App` y `Microsoft.WindowsDesktop.App` `9.0.13`. El inventario del paquete .NET no tiene una entrada `Archonia.exe`. La autorización de elevación está condicionada a instalar sin ejecutar el launcher ni el juego, y este ejecutable inicia código del launcher. Quedan pendientes las condiciones de instalación y las dependencias del juego. [Manifiestos de aplicaciones de Windows](https://learn.microsoft.com/en-us/windows/win32/sbscs/application-manifests) · [Formato de paquete .NET](https://github.com/dotnet/runtime/blob/main/src/installer/managed/Microsoft.NET.HostModel/Bundle/Manifest.cs)
- **Estado tras revisar el instalador.** En ese momento la carpeta externa contenía únicamente `ArchoniaSetup.exe`. Para inspeccionar el cliente se recurrió al paquete directo descrito a continuación.

## Paquete directo de Archonia

El 21 de noviembre de 2026 se descargó la opción oficial **Direct Package** en `D:\proyectos\archonia-client-lab\Archonia.rar`. El enlace del operador redirige a `patch.archonia.net/legacy/Archonia.rar`. La transferencia HTTPS devolvió `200`, coincidió con los `17671440292` bytes anunciados (16,46 GiB) y se comprobó la cabecera RAR. Se conservó la marca de origen de Internet. El SHA-256 calculado en el laboratorio es `bc942433d05c24a2b69e9157b74411ed235876c69b7a795b0f3f761419c661dd`. [Página oficial de descarga](https://archonia.net/download?culture=en)

Microsoft Defender completó el examen personalizado del RAR entre las 23:14 y las 23:22, con las firmas `1.463.403.0`, la protección en tiempo real activa y el examen de archivos comprimidos habilitado. Se correlacionaron los eventos `1000` y `1001` de la misma ejecución. El historial y los eventos no registraron amenazas asociadas al RAR. [Eventos de Microsoft Defender](https://learn.microsoft.com/en-us/defender-endpoint/troubleshoot-microsoft-defender-antivirus)

El inventario de RAR5 con `tar.exe` devolvió **2.086 entradas** bajo `Archonia/`. Incluye `Archonia Launcher.exe` y el archivo `Launcher/PatchVersion.txt` con valor `665`. La inspección del ejecutable de juego se hizo sobre una copia temporal, que se retiró después de leer sus metadatos.

| Elemento | Resultado de la inspección |
| --- | --- |
| `Archonia/Game/Archonia.exe` | PE x64 (`0x8664`), `18019840` bytes. `FileVersion` y `ProductVersion` figuran como `1, 0, 0, 1`. Windows informó `NotSigned`. SHA-256 `e13603c37083aaa81e357a622f9cb99b32044f922d18441660c98d87290bb1a6`. |
| `Archonia/Game/Archonia.ini` | Presente en el paquete. `ArchoniaTest.ini` no figura en el inventario. |
| `Archonia/Game/ini/` | Incluye `charactertemplateclient.ini`, `loginsettings.txt` y `RegionTemplate.ini`. |
| `Archonia/Game/world/`, `character/` y `texture/` | Se encontraron sectores `.ma1` y `.ma2`, paquetes de personaje y animación `Data.Dat` y `Reference.Dat`, y paquetes de texturas de personaje. Se verificó la presencia de estas categorías. Queda por comprobar la correspondencia entre la plantilla Knight, una zona inicial concreta y los datos cargados por ArchCore. |

El parche `665` identifica lo registrado por el launcher en ese RAR y la versión `1, 0, 0, 1` corresponde al recurso PE de `Archonia.exe`. No se pudo identificar si es el mismo artefacto que usó el mantenedor. La prueba local verificó que este cliente concreto se conecta a nuestro ArchCore fijado.

## Integridad y rutas antes de la extracción

- El 22 de noviembre se volvió a calcular el SHA-256 del RAR y coincidió con el esperado. Se verificaron las 2.086 rutas y sus tipos de entrada. El inventario registra 1.977 archivos regulares y 109 directorios bajo `Archonia/`, sin enlaces, rutas externas ni duplicados que colisionen en Windows. El total expandido es `30104201901` bytes (28,04 GiB). Había `100274171904` bytes libres antes de empezar.
- Se usó `tar.exe` de Windows, bsdtar 3.8.9. El primer intento de lectura completa a salida estándar devolvió el total de bytes previsto y señaló que no podía descomprimir una entrada de directorio de tamaño cero. Se repitió con la lista de archivos regulares. La herramienta leyó los `30104201901` bytes sin errores ni advertencias y devolvió código `0`. [Tar en Windows](https://learn.microsoft.com/en-us/windows/tar)

## Extracción y verificación en disco

- Se creó `D:\proyectos\archonia-client-lab\client` y se extrajeron los archivos con la sobrescritura desactivada. Se conservaron `Archonia.rar` y `ArchoniaSetup.exe`. Los 1.977 archivos y 109 directorios extraídos coinciden con el inventario del RAR, incluidos los tamaños de todos los archivos. Se conservó la marca de origen de Internet en los siete programas y bibliotecas extraídos como metadata de Windows, sin modificar su contenido.
- El ejecutable definitivo es `D:\proyectos\archonia-client-lab\client\Archonia\Game\Archonia.exe`. Se confirmó PE32+ x64, versión `1, 0, 0, 1`, firma `NotSigned` y SHA-256 `e13603c37083aaa81e357a622f9cb99b32044f922d18441660c98d87290bb1a6`. El examen personalizado de Defender sobre ese ejecutable terminó con los eventos `1000` y `1001`, sin registrar amenazas asociadas al laboratorio. [Eventos de Microsoft Defender](https://learn.microsoft.com/en-us/defender-endpoint/troubleshoot-microsoft-defender-antivirus)
- Las importaciones PE del cliente incluyen Direct3D 9 (`d3d9.dll`), `dxgi.dll`, la biblioteca auxiliar `d3dx9_43.dll` y `fmod.dll`. Todas las bibliotecas de importación directa se localizaron en Windows o junto al ejecutable. `D3DX9_43.dll`, `d3dx9_31.dll` y `fmod.dll` están incluidas y son x64. No apareció una dependencia directa ausente. La inspección estática deja pendientes las bibliotecas cargadas dinámicamente, la inicialización gráfica y de audio, y cualquier requisito del launcher o antitrampas. [Formato PE e importaciones](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format) · [Bibliotecas DirectX](https://learn.microsoft.com/en-us/windows/win32/dxtecharts/directx-setup-for-game-developers)
- El manifiesto del juego declara `highestAvailable`. Windows puede pedir elevación según la cuenta utilizada. La primera ejecución debe detenerse ante una solicitud de permisos o una alerta de Windows que quede fuera de la autorización. [Niveles de ejecución de Windows](https://learn.microsoft.com/en-us/windows/win32/secbp/running-with-administrator-privileges)

## Conexión al laboratorio

| Servicio | Laboratorio habitual | Instancia aislada usada en la prueba de personaje | Uso |
| --- | --- | --- | --- |
| Login TCP | `127.0.0.1:11002` | `127.0.0.1:11102` | Dirección que se introduce en el cliente. |
| Mundo TCP | `127.0.0.1:11008` | `127.0.0.1:11108` | Login anuncia esta dirección después de seleccionar el personaje. |
| MariaDB TCP | `127.0.0.1:3317` | `127.0.0.1:3327` | ArchCore accede a la base de datos. El cliente gráfico solo usa login y mundo. |

En `auth.conf`, fijar `LoginServer.Bind` en `127.0.0.1` y el puerto de login elegido. En `world.conf`, fijar `WorldServer.Bind` y `WorldServer.PublicAddress` en `127.0.0.1`, con el puerto de mundo correspondiente y `SOAP.Enabled = 0`. `PublicAddress` es la dirección anunciada al cliente. Ambos procesos deben compartir Windows o la misma máquina virtual para que sus direcciones de loopback sean las mismas. [Ajustes locales](ARCHCORE_LOCAL_SERVER.md) · [Puertos y dirección anunciada en la prueba aislada](ARCHCORE_CHARACTER_CREATION.md)

Durante la comprobación previa, `netstat -ano -p tcp` no mostró conexiones ni escuchas TCP locales en los seis puertos de la tabla. La escucha y la dirección anunciada se comprobarán de nuevo cuando se autorice el arranque.

**Archonia x64.** El mantenedor documenta que el ejecutable lee primero un archivo de texto `<ClientName>Test.ini` situado junto a él, antes de leer su lista de servidores cifrada. El ejecutable extraído contiene literalmente el nombre `ArchoniaTest.ini`. En el ensayo con elevación se creó ese archivo nuevo y el cliente conectó al puerto exclusivo `11102` indicado en él. Se conservó el `Archonia.ini` original. El ejemplo siguiente usa el puerto habitual `11002`. La instancia desechable usó `11102` y recibió el mundo en `11108`. [Guía de conexión de ArchCore](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-Installation.md#L140-L154)

```xml
<IPInfo>
  <ServerGroup>
    <GroupName>ArchCore</GroupName>
    <IP>127.0.0.1:11002</IP>
  </ServerGroup>
</IPInfo>
```

**ArchRust.** El archivo `realmlist.wtf`, junto al ejecutable o en el directorio de trabajo, puede contener `set realmlist 127.0.0.1:11002`. Para la prueba aislada, usar `127.0.0.1:11102`. La interfaz permite introducir el servidor y una cuenta local. Se puede proponer `archrust --no-client play` después de compilar el código revisado. El argumento evita cargar `Game` y permite usar los reemplazos generados y los paquetes seleccionados. [Configuración de realmlist](https://github.com/BlaMacfly/ArchRust/blob/256888eb123063e21711bde98f9572c44fed5bee/README.en.md#L87-L104) · [Argumentos de ArchRust](https://github.com/BlaMacfly/ArchRust/blob/256888eb123063e21711bde98f9572c44fed5bee/apps/archrust/src/main.rs#L29-L54)

## Datos para ver el Knight en el mundo

| Capa | Mínimo conocido y trabajo pendiente |
| --- | --- |
| Cuenta, esquema y personaje | Baseline y migraciones de los cuatro esquemas, una cuenta local sin GM y la fila `archcore_world.character_data_table` con TID `96`, nombre `Knight` y `{"Race":"1","Class":"1"}`. Esta fila ya bastó para el protocolo. El catálogo `character_customize` quedó vacío en esa prueba. Queda comprobar qué opciones de creación ofrece cada GUI con esos datos. |
| Modelo y selección | Una representación propia basta para confirmar que el cliente sabe dónde dibujar al avatar. Para visualizar el Knight con su aspecto original hacen falta tablas que resuelvan el TID, modelos, texturas y, para animarlo o personalizarlo, animaciones y variantes de cara y pelo. ArchRust documenta reemplazos con glTF y su manifiesto incluye un ejemplo comentado para el TID 96. Si falta `ini/LoginSettings.txt`, el código omite la preparación de la escena 3D de selección. Su interfaz de login independiente y sus reemplazos visuales permiten empezar con una prueba más pequeña. |
| Zona visible | Se necesita terreno visible y una posición de aparición válida sobre él. El origen `(0, 0, 0)` funcionó para `FINISH_ENTER` con el mapa de servidor vacío. Elegir una superficie transitable con el terreno autorizado de la misma versión del cliente. Usar `StartPosition.1.X/Y/Z` en `world.conf` para personajes humanos nuevos. Evaluar `map_segment`, `map_height` y las reglas de región para las comprobaciones del servidor, y verificar el recorrido y las colisiones del cliente en la escena. |
| Interfaz y contenido | El MVP visual requiere entrada de credenciales, selección o creación, escena de mundo, avatar y cámara. Los NPC, misiones, objetos, audio y la interfaz original completa se pueden evaluar después. Si ArchRust muestra valores inconsistentes, revisar si necesita tablas en `server-data/` exportadas desde datos propios, antes de importar catálogos adicionales. |

[Plantilla, tablas y aparición verificadas localmente](ARCHCORE_CHARACTER_CREATION.md) · [Formatos gráficos y de terreno leídos por ArchRust](https://github.com/BlaMacfly/ArchRust/blob/256888eb123063e21711bde98f9572c44fed5bee/docs/ASSETS-NON-FOURNIS.en.md#L10-L55) · [Ejemplo de manifiesto glTF](https://github.com/BlaMacfly/ArchRust/blob/256888eb123063e21711bde98f9572c44fed5bee/free-assets/patch.toml#L23-L35) · [Escena de selección](https://github.com/BlaMacfly/ArchRust/blob/256888eb123063e21711bde98f9572c44fed5bee/crates/archrust-engine/src/app.rs#L1031-L1054) · [Mapa del servidor](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/world/map.rs#L41-L115) · [Exportación de tablas](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-Installation.md#L83-L100)

## Launcher, seguridad y permisos

- El operador publica actualizaciones mediante launcher, protección del ejecutable y un sistema antitrampas. Las fuentes no permiten determinar si el build disponible exige actualización, autenticación externa, una comprobación de integridad o una sesión antitrampas para usar la configuración local. La guía de ArchCore también indica que su cliente de referencia se ejecutaba con elevación. Si un build autorizado exige un componente externo o interviene la protección, la prueba debe quedar pendiente hasta que exista un método soportado. [Nota oficial del launcher y protección](https://archonia.net/news/48/patch%20311%20-%20312) · [Aviso oficial sobre antitrampas](https://archonia.net/news/39/new%20anti-cheat%20system%20in%20place%20%E2%80%93%20final%20warning) · [Guía del mantenedor](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-Installation.md#L140-L154)
- La página del operador acredita la procedencia de su descarga, pero los términos consultados no establecen una autorización para conectar ese cliente a ArchCore ni redistribuir sus recursos. La licencia de ArchRust cubre su código. Cada paquete gráfico requiere revisar sus créditos y licencia. Para la primera prueba usar sustitutos generados o propios. El paquete `free-assets` del pin incluye una textura con atribución cuya licencia se marca pendiente de confirmación. [Términos de Archonia](https://archonia.net/termsofuse?culture=en) · [Reglas del servicio público](https://archonia.net/guide/rules/in-game-rules/english) · [Créditos del paquete ArchRust](https://github.com/BlaMacfly/ArchRust/blob/256888eb123063e21711bde98f9572c44fed5bee/free-assets/CREDITS.md)
- Un cliente antiguo o de terceros puede ejecutar código nativo, instalar componentes o conectar a otros destinos. Para una futura prueba, comprobar origen, firma cuando exista y SHA-256 publicado del artefacto autorizado. Ejecutar en un entorno Windows aislado sin secretos ni acceso al laboratorio habitual, observar destinos de red y usar una cuenta exclusiva de la prueba, sin permisos GM. Mantener activas las protecciones del sistema y detener la prueba si requiere excepciones o aparecen destinos externos no previstos. El cifrado heredado del protocolo justifica mantener las escuchas en loopback y usar contraseñas exclusivas del laboratorio.

## Estructura del cliente para la prueba

La carpeta externa `D:\proyectos\archonia-client-lab` contiene los dos archivos de distribución y la extracción en `client\Archonia\`. Las rutas de la tabla son relativas a esa raíz.

| Ruta | Función |
| --- | --- |
| `Game\Archonia.exe` | Ejecutable gráfico x64 identificado en el RAR. |
| `Game\ArchoniaTest.ini` | Archivo de texto de conexión local que se preparará junto al ejecutable. El XML y el puerto del laboratorio se describen en la sección de conexión. |
| `Archonia Launcher.exe` y `Launcher\` | Launcher y estado de actualización del operador. Queda por confirmar el método soportado para iniciar este build en el laboratorio. |
| `Game\ini\` | `charactertemplateclient.ini`, `loginsettings.txt`, `RegionTemplate.ini` y `COption.ini`, entre otros. |
| `Game\character\`, `Game\character\animation\` y `Game\texture\` | Paquetes de modelos, caras, pelo, animaciones y texturas del cliente. |
| `Game\world\`, `Game\object\` y `Game\effect\` | Terreno, modelos de objetos y efectos. En `world` se contaron 192 archivos `.ma1` y 366 archivos `.ma2`. |

[Estructura del cliente de referencia](https://github.com/BlaMacfly/ArchRust/blob/256888eb123063e21711bde98f9572c44fed5bee/docs/ASSETS-NON-FOURNIS.en.md#L10-L25) · [Configuración de Archonia documentada por ArchCore](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-Installation.md#L140-L156)

## Procedimiento para repetir el ensayo con Archonia x64

La extracción está completa. Se comprobó el arranque directo con la elevación autorizada para el ensayo registrado abajo. Cualquier ejecución posterior debe acordarse sin cambiar el archivo original ni las protecciones de Windows. Queda pendiente aclarar con el operador las condiciones de uso local.

1. **Revisar el arranque.** Mantener el paquete extraído separado de la base de datos y del repositorio. Confirmar con el operador las condiciones de uso local y la forma de abrir el cliente para este build. Verificar el hash de `Game\Archonia.exe` antes de la primera ejecución. Mantener las protecciones de Windows activas y detenerse si aparece una alerta, una solicitud de elevación sin autorización o una actualización no prevista. En una VM, alojar cliente y servidor dentro de la misma VM. [Soporte del operador](https://archonia.net/support)
2. **Preparar la conexión.** Con el cliente cerrado, guardar una copia identificada si ya existe `Game\ArchoniaTest.ini`. Crear o editar ese archivo de texto junto a `Game\Archonia.exe` con el XML de la sección de conexión. Para la instancia de prueba usar `127.0.0.1:11102` en `IP`. Usar el método de arranque que confirme el operador. Si el build ignora el INI, exige una actualización no prevista o conecta a otro destino para autenticar, cerrar el cliente y registrar el bloqueo. [Configuración documentada por ArchCore](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-Installation.md#L140-L154)
3. **Preparar la instancia desechable.** Usar el binario de ArchCore ya compilado y MariaDB existente como herramientas. La prueba necesita un directorio de datos, opciones de MariaDB y archivos `auth.conf` y `world.conf` separados, con MariaDB en `3327`, login en `11102` y mundo en `11108`, todo en `127.0.0.1`. Configurar `WorldServer.PublicAddress = "127.0.0.1"` y desactivar SOAP. Verificar que `Database.Port` de ambos servicios coincide con la instancia desechable. Reutilizar el esquema y la plantilla Knight TID `96` documentados, y prever una cuenta temporal sin GM con un personaje de prueba o con permiso para crearlo desde la GUI. Alinear la posición inicial con una zona cuyo terreno y recursos estén autorizados y coincidan con el cliente. La plantilla y `FINISH_ENTER` ya se verificaron con el simulador. Faltan la escena y los datos de suelo de la zona. [Instancia y datos ya probados](ARCHCORE_CHARACTER_CREATION.md) · [Carga de segmentos y alturas](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/tools/import.rs#L500-L525)
4. **Arrancar los servicios en orden.** En la instancia de prueba, iniciar primero `mariadbd.exe --defaults-file=<opciones-de-prueba> --console` y confirmar una consulta autenticada y que `@@datadir` y `@@port` son los desechables. En otra consola, apuntar `ARCHCORE_ROOT` y `ARCHCORE_CONF_DIR` a los directorios de prueba, ejecutar `archcore.exe db-check` y, si termina correctamente, `archcore.exe all`. Consultar `Get-NetTCPConnection -State Listen -LocalPort 3327,11102,11108` y comprobar que cada escucha usa `127.0.0.1` y pertenece al PID esperado. Confirmar que login anuncia el mundo en `127.0.0.1:11108`. Para el laboratorio habitual, desde la raíz del proyecto se puede ejecutar `.\scripts\archcore-lab.ps1` con `Start`, `Status` o `Stop`. Esos controles gestionan la configuración y los puertos habituales. [Controles y arranque manual](ARCHCORE_LOCAL_SERVER.md)
5. **Autenticar, seleccionar y entrar.** En el cliente, seleccionar el grupo del laboratorio y escribir las credenciales temporales sin guardarlas en EasyLogin. Confirmar en la consola de login la línea `authentifié` y que se muestra el catálogo o personaje de prueba. Crear el Knight desde la GUI si la cuenta está vacía o seleccionar el Knight ya preparado. Registrar el CID, la conexión al puerto de mundo y la línea `est en jeu` de la misma sesión de mundo. En el código, esta línea se escribe después del envío de `FINISH_ENTER`. El hito gráfico requiere ver el Knight sobre el suelo y recuperar el mismo personaje al volver a entrar. [Log de autenticación](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/login.rs#L263-L299) · [Finalización de entrada](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/world/mod.rs#L945-L967)
6. **Verificar movimiento y parada.** Desde un punto de referencia visible, caminar una distancia corta, esperar a que el Knight se detenga y cerrar la sesión. Buscar en la consola de ArchCore `premier déplacement reçu` y `quitte le monde en` con el mismo identificador de sesión de mundo. La primera línea indica que el servidor procesó el paquete de movimiento `0x40`. La segunda incluye las coordenadas finales X/Z y el contador de desplazamientos. Comparar esas coordenadas con la posición de aparición conocida o comprobada al entrar. Si hace falta ver destino y parada, arrancar la instancia de prueba con `ARCHCORE_TRACE=1` solo en la consola de ArchCore. Conservar únicamente las líneas de evidencia, sin credenciales, tokens ni trazas de paquetes. [Logs de salida y movimiento](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/world/presence.rs#L43-L128) · [Activación de trazas](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/log.rs#L5-L13)
7. **Revertir el ensayo.** Cerrar el cliente y el launcher. Detener ArchCore con Ctrl+C en su consola y apagar la MariaDB de prueba con `mariadb-admin.exe`, usando el archivo privado de administración de esa instancia. Comprobar que los tres puertos de prueba quedan libres. Cerrar las consolas de prueba para retirar las variables locales. Restaurar la copia de `ArchoniaTest.ini` si ya existía o retirar únicamente el archivo creado para la prueba. Si procede desinstalar, usar el método del operador. Tras confirmar el directorio de datos y con autorización de limpieza, retirar únicamente la instancia y los artefactos desechables. [Parada manual del laboratorio](ARCHCORE_LOCAL_SERVER.md)

## Primer ensayo gráfico del parche 665

El 22 de noviembre de 2026 se volvió a comprobar el SHA-256 de `Game/Archonia.exe`, la versión del parche y el estado de Defender. El hash coincidió con el de la extracción. Defender continuó activo y no registró detecciones asociadas al laboratorio. El ensayo usó una cuenta estándar de Windows en una sesión interactiva.

| Etapa | Resultado observado |
| --- | --- |
| MariaDB desechable | Se comprobó el directorio de datos nuevo, el PID y el puerto `127.0.0.1:3327` antes de las escrituras. `db-init` y `db-check` completaron 55 migraciones y 4 referencias iniciales de esquema. |
| Datos de prueba | Se creó una cuenta temporal sin permisos GM. Se preparó un Knight con TID `96` y CID `1` en `(0, 0, 0)`. La base de mundo tenía cero sectores de mapa y no se importó contenido original. |
| ArchCore | Se verificaron las escuchas exclusivas de login en `127.0.0.1:11102` y mundo en `127.0.0.1:11108`. La lista de mundos de la base desechable quedó configurada para anunciar `127.0.0.1:11108`. |
| Configuración del cliente | Se creó un `Game/ArchoniaTest.ini` nuevo con el XML del mantenedor y el puerto `11102`. El cliente quedó intacto. Al finalizar se comprobó el hash del INI generado y se retiró únicamente ese archivo. |
| Arranque directo | La llamada de creación de proceso, sin pasar por el launcher ni solicitar elevación, devolvió `740`: «La operación solicitada requiere elevación». El proceso no se creó y no apareció una ventana del juego. |
| Conexión y juego | Quedaron sin probar la lectura del INI, la conexión TCP, la autenticación, la selección del Knight, `FINISH_ENTER`, el terreno y el movimiento desde la interfaz. Los logs de ArchCore no mostraron autenticación, entrada al mundo ni movimiento. |
| Limpieza | Se cerró el proceso de ArchCore propio de la prueba antes de que hubiera sesiones de juego. MariaDB se apagó ordenadamente. Tras verificar la ruta y el marcador de la instancia desechable, se retiraron su base, la cuenta y las configuraciones temporales. Se verificó la ausencia de procesos y escuchas del laboratorio. |

El error `740` se observó antes de que Windows creara el proceso. Tras recibir autorización específica para elevar el ejecutable del juego se repitió el ensayo. [Niveles de ejecución de Windows](https://learn.microsoft.com/en-us/windows/win32/secbp/running-with-administrator-privileges)

## Segundo ensayo gráfico con elevación autorizada

El 22 de noviembre de 2026 se repitió el ensayo con el mismo `Game\Archonia.exe` del parche `665` y ArchCore fijado a `ad280a6efc069526fc58445e5397d52a0e809500`. Se aplicaron las migraciones a otra instancia desechable y se preparó una cuenta sin GM con un Knight TID `96` y CID `1`. La única solicitud de elevación fue para ese ejecutable verificado. No se inició el launcher.

| Etapa | Resultado observado |
| --- | --- |
| Arranque | Windows creó el proceso del juego. Se observó una ventana que respondía y mostraba los campos de usuario y contraseña. |
| Configuración local | Con el INI temporal indicando `127.0.0.1:11102`, el proceso de Archonia abrió conexiones a ese puerto y al mundo en `127.0.0.1:11108`. |
| Autenticación | ArchCore registró la autenticación y se verificó `account.last_login` en la MariaDB desechable. La cuenta se usó desde la interfaz gráfica. |
| Personaje y mundo | Se vio el Knight `LabKnight` en la escena del mundo. El registro `est en jeu` confirma que el servidor alcanzó el punto posterior al envío de `FINISH_ENTER`. MariaDB mostró `characters.last_played` informado y el token de entrada consumido. [Finalización de entrada en ArchCore](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/world/mod.rs#L945-L967) |
| Terreno y movimiento | La ventana mostró la malla de terreno y una roca del paquete, además del modelo del Knight. ArchCore registró el primer paquete de movimiento. La última posición persistida fue `(0, 13625.5234375, 0)`. El cambio de altura y el mensaje del servidor confirman actividad de movimiento, mientras que quedó pendiente demostrar desplazamiento horizontal y colisiones en una zona inicial preparada. La base desechable tenía cero sectores de mapa de servidor. |
| Fin del ensayo | ArchCore se detuvo y MariaDB se apagó ordenadamente. Quedaron libres los tres puertos de prueba. Se verificó la identidad del directorio desechable y se retiró la base con la cuenta temporal. La consola no pudo cerrar el cliente elevado y se esperó a que terminara. Después se retiraron el INI de prueba y las capturas temporales. Se confirmó que el ejecutable conserva su SHA-256 y que Defender sigue activo y sin detecciones asociadas. |

La compatibilidad observada cubre login, selección, entrada y renderizado con este cliente gráfico concreto. Sigue pendiente preparar una zona inicial con datos de servidor y verificar allí suelo, colisiones y recorrido persistido.

## Sesión manual persistente del parche 665

El 22 de noviembre de 2026 se usó la instancia `archonia-manual-session` del laboratorio externo, con MariaDB en `127.0.0.1:3327`, login en `127.0.0.1:11102` y mundo en `127.0.0.1:11108`. Esta sesión conserva sus datos entre arranques.

| Comprobación | Resultado |
| --- | --- |
| Creación y entrada | Se creó un Knight en la interfaz de Archonia x64, se seleccionó y se entró al mundo. El log registra una solicitud de creación con TID `96` y la línea `est en jeu` posterior a `FINISH_ENTER`. |
| Escena y movimiento | En pantalla se vio el Knight y el terreno original. El personaje quedó entre una montaña y una roca. ArchCore registró un primer paquete y, al salir, seis desplazamientos con X/Z finales `(0, 0)` en el log. La posición inicial es una hipótesis para explicar el bloqueo. La causa y el desplazamiento horizontal siguen pendientes de confirmar. |
| Conservación de datos | Al retomar el trabajo se comprobó que los PID registrados habían terminado, que los tres puertos estaban libres y que el directorio `db` conservaba los archivos de la tabla `characters`. El log de ArchCore registra salida con código `0`. La próxima lectura SQL confirmará la fila y sus coordenadas exactas cuando se autorice el arranque. |
| Gestor local | La copia recuperada `lab.ps1` permanece en la carpeta externa y pasó el análisis sintáctico de PowerShell. Antes de reutilizar su arranque y parada conviene verificar la reversión de un arranque parcial y que ambos comandos comprueban el destino de administración de MariaDB. |

[Creación y posición inicial en ArchCore](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/login.rs#L418-L481) · [Registro de movimiento y salida](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/world/presence.rs#L41-L128)

## Ensayo de aparición en Anchorville

El 22 de noviembre de 2026 se hizo una copia en frío de la sesión manual bajo `archonia-knight-spawn-movement` en el laboratorio externo. Se compararon los SHA-256 de los 408 archivos de la base original y la copia antes del arranque. La copia tiene permisos de acceso restringidos y usa MariaDB en `127.0.0.1:3337`. Antes de la escritura se comprobó por SQL que el directorio de datos activo era el de la copia. Login y mundo usan `127.0.0.1:11102` y `127.0.0.1:11108` para conservar la lista de mundos y el `ArchoniaTest.ini` ya configurados.

| Comprobación | Resultado |
| --- | --- |
| Personaje conservado | MariaDB devolvió el Knight CID `1`, TID `96`, nivel `1`, con posición `(0, 13625.5234375, 0)` en la copia inicial. |
| Velocidad de marcha y carrera | Los campos JSON `Movement Walk` y `Movement Run` están ausentes y no hay una fila TID `96` en `character_template`. El código crea la plantilla con ambos factores en cero en este caso. |
| Posición candidata | El punto humano de referencia de ArchCore cae en el sector `(325, 389)`. La lectura en memoria del terreno del parche `665` en `b002024x.ma2` dio una altura interpolada de `4632.007`. La base de mundo de la prueba informó cero segmentos y cero sectores con altura. |
| Escritura en la copia | Se actualizó una sola fila, el CID `1`, y SQL devolvió `(-475955, 4632, -66219)`. Se conservaron las velocidades. Los 408 SHA-256 de la base original volvieron a coincidir después del arranque de ArchCore. |
| Primera prueba gráfica | El cliente entró en el sector `(325, 389)` y la sonda registró 73 órdenes de movimiento, entre ellas 24 destinos de clic. Todas las muestras de posición del servidor siguieron en `(-475955, 4632, -66219)` mientras el Knight estuvo conectado. |
| Cierre de la primera prueba | Al salir, SQL mostró `(-476247, 4609.40771484375, -66252.46875)`. Coincide con el último destino pendiente. Esta revisión de ArchCore asigna ese destino al salir, así que el cambio guardado por sí solo no demuestra un recorrido. |
| Segunda prueba, datos iniciales | Se añadieron solo las cadenas `Movement Walk = "5000"` y `Movement Run = "6000"` al JSON del Knight TID `96` en la copia. SQL confirmó ambas cadenas y la posición que se había guardado al salir del primer ensayo. ArchCore se detuvo normalmente y arrancó de nuevo con la misma MariaDB de pruebas. Las velocidades de prueba equivalen a 500 y 600 unidades del mundo por segundo según el código de movimiento. |
| Segunda prueba, recorrido | En la sonda, el Knight pasó por `(-476165, 4615, -66457)` y `(-475735, 4649, -66380)`, con un cambio de dirección entre ambos puntos. Recibió 22 órdenes de carrera por clic y avanzó mientras estuvo conectado. La velocidad horizontal media en 14 intervalos sin cambio de destino fue de aproximadamente 595,7 unidades por segundo. |
| Segunda prueba, guardado y reconexión completa | La última muestra antes de salir mostró al Knight detenido en `(-474927, 3355, -50067)`. MariaDB devolvió `(-474926.59375, 3354.62890625, -50067.45703125)` después de la salida. Tras cerrar completamente Archonia, abrirlo otra vez e iniciar sesión con la misma cuenta, la primera muestra del Knight coincidió con esa posición a la precisión del log. |

El gestor de la sesión manual se revisó por lectura. La prueba usa comandos específicos para la copia porque el gestor anterior puede dejar MariaDB activa tras un arranque parcial y su parada no vuelve a validar el destino del archivo de administración. La sonda se habilita solo para la copia y sus archivos permanecen fuera de Git.

El ensayo confirma avance en X/Z con clics en modo carrera, parada y recuperación del punto guardado desde un proceso nuevo de Archonia. La cadena de marcha quedó confirmada por SQL y el código que carga los factores. La sonda de esta sesión solo recibió órdenes en modo carrera. Sigue pendiente comprobar la marcha por separado y recuperar un recorrido tras reiniciar el servidor.

[Referencia de Anchorville y sectores](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/world/map.rs#L124-L130) · [Aplicación de velocidades](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/character.rs#L147-L179) · [Sonda de movimiento](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/probe.rs#L135-L150) · [Guardado al salir](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/world/presence.rs#L41-L63)

### Bloqueo al volver a selección de personajes

El usuario observó el bloqueo con Archonia x64 parche `665`, ArchCore `ad280a6` y la copia aislada de Anchorville.

1. Abrir `Archonia.exe` con el grupo local `ArchCore`, iniciar sesión y entrar al mundo con el Knight existente.
2. Dejar al Knight detenido y fuera de combate. Abrir el menú de salida y escoger la opción de volver a la selección de personajes.
3. El cliente queda en una pantalla con un mensaje similar a «Attempting to reconnect». Se esperaba que mostrara la lista de personajes en la misma ventana.
4. Como salida comprobada, cerrar completamente `Archonia.exe`, abrirlo de nuevo con el mismo grupo, iniciar sesión y elegir el mismo Knight. El personaje reaparece en el punto guardado.

#### Flujo que implementa ArchCore

| Paso | Mensaje o efecto |
| --- | --- |
| Cliente → mundo, puerto `11108` | `AgpmReturnToLogin` (`0x2F`), op `1`, con el CID. Mundo devuelve op `2` si el personaje está muerto o en combate. |
| Mundo → cliente | Si acepta, genera una clave de un solo uso con 60 segundos de vigencia por defecto y envía `0x2F` op `5`. El campo `4` lleva `ReturnToLogin.LoginAddress` si está configurado. Con el valor vacío el campo se omite y el diseño espera que el cliente reutilice su dirección de login. |
| Liberación del personaje | Mundo guarda la posición y retira al jugador de la sesión activa de inmediato. Cierra el socket de mundo aproximadamente dos segundos después. Tras una desconexión imprevista, el flujo de reconexión de mundo `0x63` puede retener al jugador hasta 60 segundos. |
| Cliente → login, puerto esperado `11102` | Después de establecer el cifrado de la nueva conexión, el cliente debe enviar `0x2F` op `6`. Login contrasta y consume la clave, y envía `AGPMLOGIN` op `0` para iniciar la autenticación. |
| Login → cliente | Tras autenticar de nuevo con `AGPMLOGIN` op `1`, login envía `0x2F` op `7`. El cliente vuelve a pedir la lista de personajes y debe mostrarla en el mismo proceso. |

[Flujo de mundo](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/world/return_login.rs#L61-L98) · [Reconexión de mundo](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/world/reconnect.rs#L60-L95) · [Validación en login](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/login.rs#L212-L240) · [Confirmación de vuelta tras autenticar](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/login.rs#L288-L304)

#### Evidencias del laboratorio

Archonia x64 parche `665` tiene `127.0.0.1:11102` en `ArchoniaTest.ini`. El servidor anuncia mundo en `127.0.0.1:11108` y los dos servicios de juego están ligados a loopback. La instancia de Anchorville usa MariaDB en `127.0.0.1:3337`. En el ensayo del bloqueo, `world.conf` carecía de `ReturnToLogin.LoginAddress` y el gestor había limpiado las variables `ARCHCORE_*` heredadas. Con el valor predeterminado vacío, op `5` omite el campo de dirección de login. [Valores predeterminados y lectura de la opción](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/config.rs#L805-L814)

En el ensayo anterior, el log registró que mundo tramitó el regreso y guardó la posición. Cerró el socket dos segundos después. Mundo aceptó tres conexiones nuevas a los 2, 7 y 12 segundos desde la solicitud, todas en `11108`. Las tres completaron el cifrado y se cerraron en el mismo segundo de su apertura. Login no aceptó una conexión nueva hasta que se abrió de nuevo Archonia y se hizo un login ordinario. En el intento de retorno no registró validación ni rechazo de op `6`. Los logs en uso permiten identificar el servicio y el cifrado, pero no el tipo exacto del último paquete de los reintentos de mundo.

Una consulta de solo lectura encontró una clave de retorno vencida que seguía presente en la cuenta de prueba. El diagnóstico registró su presencia y vigencia sin leer ni guardar su valor. El desvío hacia mundo sitúa el bloqueo antes de la validación en login. La hipótesis principal es que, con op `5` sin dirección explícita, el parche `665` no completa el traspaso al puerto `11102` y termina reintentando contra mundo. Validar la dirección explícita permitirá comprobar si basta el cambio de configuración.

Se dejó listo un observador de sockets TCP y eventos filtrados del servidor durante diez minutos. Durante esa ventana no se abrió Archonia y la reproducción en vivo quedó pendiente. La secuencia anterior procede del ensayo gráfico previo y de los logs conservados.

El simulador de ArchCore espera op `5`, pero al reconectar construye por su cuenta la dirección a partir del puerto configurado de login. Sirve para comprobar el intercambio de op `6` y op `7` con una dirección conocida. La selección de destino de Archonia con el campo `4` omitido se comprueba en la prueba gráfica. [Simulador de retorno](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/tools/sim/quickbelt.rs#L117-L146)

#### Cambio de configuración candidato y validación

La primera prueba de solución consiste en enviar al cliente la dirección local de login en op `5`. El cambio candidato es añadir solo esta línea al `world.conf` de la copia de Anchorville.

```ini
ReturnToLogin.LoginAddress = "127.0.0.1:11102"
```

La opción ya existe en esta revisión y ArchCore lee la configuración al arrancar. El ensayo conserva la instancia de MariaDB y el mismo Knight. [Construcción de op `5`](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/world/return_login.rs#L39-L47) · [Carga de configuración al arrancar](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/server.rs#L7-L14)

1. Guardar una copia del `world.conf` actual y comprobar por lectura el CID y la posición guardada. Aplicar la línea autorizada y reiniciar ArchCore con el mismo directorio de datos.
2. Abrir Archonia manualmente, entrar con el Knight y seleccionar volver a personajes mientras esté detenido y fuera de combate.
3. Correlacionar la aceptación en mundo con una nueva conexión a `127.0.0.1:11102`, el cifrado establecido y la validación de op `6`. Si la traza está disponible, verificar también op `7`. Registrar solo operaciones, horas y extremos TCP.
4. Confirmar que la lista aparece en el mismo proceso de Archonia. Volver a entrar con el mismo Knight, comparar su posición y repetir el regreso una segunda vez. Si el cliente llega a login pero falta op `6`, seguir el cifrado y el procesamiento de op `5` antes de considerar cambios en Rust. Si op `6` llega y se valida, seguir op `7` y la petición de lista.

#### Ensayo con la dirección explícita

Se respaldó el `world.conf` de la copia de Anchorville y se verificó que el único cambio fue añadir `ReturnToLogin.LoginAddress`. Se reinició solo ArchCore. MariaDB mantuvo su PID y hora de inicio, y SQL devolvió el mismo Knight en la posición guardada. Los avisos del nuevo proceso identificaron el `world.conf` de la copia y mantuvieron la vigencia predeterminada de 60 segundos. La clave de dirección se leyó sin avisos de ausencia o de clave desconocida. El cliente quedó listo para que el usuario probara manualmente.

| Observación durante la prueba manual | Evidencia |
| --- | --- |
| Salida de mundo | ArchCore aceptó el retorno y preparó op `5`. El Knight ya estaba detenido. La última muestra de posición y la fila guardada por MariaDB coincidieron a la precisión del log. SQL devolvió `(-476830.15625, 4434.2353515625, -56888.65234375)`. Mundo cerró su socket dos segundos después. |
| Nuevo destino | El mismo proceso de Archonia abrió un TCP nuevo a `127.0.0.1:11102` y login lo aceptó como sesión `#3`. La conexión inicial de login, `#1`, seguía abierta cuando llegó la nueva. |
| Cifrado y op `6` | Al iniciar el retorno, login registró una trama que no pudo descifrar en la conexión inicial `#1`. El error indica que tras descifrar faltaba el marcador `0xD6`. En la conexión nueva `#3` no quedó registrado un cifrado establecido. Login no registró validación ni rechazo de op `6`, y la clave permaneció en la base hasta vencer. El diagnóstico nunca leyó su valor. |
| Cierre manual de Archonia | Las dos conexiones de login se cerraron juntas. El log de `#3` terminó con cero paquetes contabilizados. La conexión inicial `#1` terminó con once, que incluyen su login ordinario. |

El 22 de noviembre, en hora peninsular, login aceptó `#1` desde el puerto de cliente `50775` a las `11:53:50`. El cifrado y la autenticación ordinaria se completaron en ese mismo segundo. A las `11:54:13`, mundo tramitó el retorno, login aceptó `#3` desde `60809` y registró el error de descifrado en `#1`. A las `11:54:15` se cerró mundo. Las dos conexiones de login se cerraron a las `12:02:31`, cuando el usuario cerró el cliente. Los archivos de diagnóstico registran las horas en UTC.

Los eventos de sockets y los avisos filtrados se conservaron fuera de Git en `.local/return-login-address-trial.log` y `.local/return-login-address-warnings.log`. Entre los avisos hubo un paquete de mundo `0x5C` sin manejador durante la entrada inicial. Ocurrió antes del intento de retorno y el Knight pudo entrar y moverse.

#### Qué se sabe del cifrado

`net::run_session` crea un `CryptoSession`, un acumulador de tramas y un manejador del servicio por cada TCP aceptado. `LoginService::connect` crea un `LoginConn` sin autenticación previa. En el login ordinario, el cliente inicia `AGPMSTARTUPENCRYPTION` (`0x48`) op `0` en claro. `net::startup_encryption` responde con ops `6` y `1`. Al recibir op `2` en ese mismo socket, completa el estado Blowfish y envía op `3` cifrada. El retorno necesita ese mismo intercambio antes de que `LoginConn::on_return` pueda recibir `0x2F` op `6`.

`LoginConn::world_enter` envía la entrada a mundo y deja abierta la conexión inicial. Esta conserva su cifrado mientras está abierta. En cambio, la conexión de retorno empieza con un estado propio y vacío. Al cerrar un TCP, `run_session` termina su tarea de escritura y libera su estado al desaparecer sus referencias. El código revisado no comparte los cifradores de ambos sockets ni cierra uno al aceptar el otro. [Estado por conexión y cierre](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/net.rs#L242-L286) · [Procesamiento del cifrado](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/net.rs#L409-L449) · [Transferencia inicial a mundo](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/login.rs#L552-L584)

**Confirmado.** En `#3` se completó TCP y no llegó a procesarse ningún paquete válido, incluido `0x48` op `0`. El contador de cierre se incrementa tras extraer una trama completa y obtener un encabezado válido. Puede quedar en cero si el socket estuvo inactivo o si recibió datos que nunca llegaron a ese punto. En `#1` llegó una trama cifrada que falló antes de leer el encabezado. Su operación queda indeterminada. Los once paquetes de `#1` son un total de toda la sesión y no permiten ubicar un op `0` de retorno. La traza habitual de paquetes entrantes tampoco resuelve esto por sí sola porque las tramas de inicio de cifrado se desvían al manejador antes de esa traza. [Contador y despacho de tramas](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/net.rs#L288-L361) · [Comprobación de la trama descifrada](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore-net/src/framing.rs#L68-L91)

**Hipótesis pendiente.** El cliente abre el socket de retorno y, durante la transición, sigue enviando tráfico al login inicial o usa un contexto de cifrado que ese socket no puede leer. También cabe que llegue una lectura parcial a `#3`. Los logs no permiten afirmar que el op `0` se enviara a `#1` ni descartar que el cliente no lo enviara. La dirección explícita resolvió el destino TCP. Las opciones de retorno de esta revisión cubren la dirección y la vigencia de la clave. Cambiar la vigencia no explica la ausencia del inicio de cifrado.

#### Diagnóstico mínimo y validación de una solución

Conservar `ReturnToLogin.LoginAddress` y preparar, tras autorización, una traza temporal en una instancia de ArchCore separada, ligada a loopback y con datos de prueba independientes. En `net.rs`, `run_session` debe registrar por socket la hora, el identificador, el puerto remoto, número de bytes leídos, número de tramas completas y resultado del descifrado. En `startup_encryption` basta registrar ops `0` y `2` después de decodificarlas, las respuestas encoladas y el estado final del cifrado. En `login.rs`, las marcas de `LoginConn::on_return` y `LoginConn::user_login` permiten corroborar op `6` y la confirmación op `7`. Limitar la traza a esos eventos y omitir los volcados hexadecimales de los errores durante el ensayo. Guardar las métricas fuera de Git. No se necesitan contraseñas, valores de claves ni contenido de tramas.

- Si `#3` no recibe bytes o solo recibe datos incompletos, el siguiente paso es comprobar el envío del cliente tras op `5`. Si op `0` se observa en el socket anterior, evaluar en la instancia de prueba una variante que cierre ese login después de encolar la transferencia inicial en `LoginConn::world_enter`. La variante debe demostrar primero que la entrada normal al mundo sigue funcionando.
- Si `#3` recibe op `0` y falta op `2`, comprobar en `net::startup_encryption` qué respuestas se encolan y verificar que el escritor las entrega. Si el cifrado se completa y falta op `6`, seguir el envío del cliente y el despacho hacia `LoginConn::on_return`. Una corrección de Rust dependerá de cuál de esos pasos falle.

La aceptación requiere entrar con el Knight, moverlo hasta un punto que pueda comprobarse, detenerlo y pulsar «Cambiar personaje». La lista debe aparecer en el mismo proceso de Archonia. Al seleccionar el mismo CID se debe recuperar ese punto. Repetir el ciclo completo y comprobar en ambos intentos el saludo, op `6`, la autenticación y op `7`. Preparar una cuenta y un Knight equivalentes en los datos de prueba o usar una copia consistente autorizada de la sesión. En el laboratorio persistente sigue disponible el procedimiento de cerrar y abrir Archonia.

#### Binario de diagnóstico local

La copia de trabajo está en `.local/archcore-return-diagnostics`. Se copiaron y verificaron 246 archivos necesarios para compilar desde el submódulo `ad280a6`. El binario se compiló offline con Cargo `1.100.0` y el lockfile fijado. Está en `.local/archcore-return-diagnostics/target/x86_64-pc-windows-msvc/release/archcore.exe` y su SHA-256 es `bb54436229cba968375f230378570c4154f9ee4b12e524b6d7af9f5dc4a09c67`. Se verificó `--help` con y sin el modo de diagnóstico. El ejecutable habitual conserva su SHA-256 `9ac727009c2d558c0c82dff247cb7a51acf9ec85c628efe6c006d2a6ac7ebbc9` en el directorio `target` del laboratorio externo.

Pasaron las dos pruebas unitarias existentes del separador de tramas y el cifrado, y la prueba de construcción de los paquetes de retorno. La prueba instrumentada comprobó después la traza con Archonia.

Para repetir la compilación, ejecutar este comando desde la copia.

```powershell
rustup run stable-x86_64-pc-windows-msvc cargo build --offline --locked --release -p archcore --target x86_64-pc-windows-msvc --target-dir .\target
```

La copia modifica tres archivos. `net.rs` instrumenta la recepción, el escritor TCP y el inicio de cifrado. `log.rs` habilita el modo con `ARCHCORE_HANDSHAKE_DIAGNOSTICS=1` y limita la salida a diagnósticos de metadatos. `probe.rs` desactiva la sonda general mientras ese modo está activo. Se conservan los pasos de autenticación, las operaciones de red y la política de cierre.

| Evento esperado | Qué permite comprobar |
| --- | --- |
| `tcp_accepted`, `tcp_eof`, `tcp_local_close`, `tcp_closed` | Correlacionar servicios e identificadores de conexión por hora UTC y puertos. El cierre incluye el total de bytes leídos y paquetes contabilizados. |
| `tcp_read bytes=…` y `frame_split complete_frames=…` | Distinguir un socket sin lecturas de uno que recibió datos y quedó a la espera de completar una trama. |
| `header valid=…`, `decrypt_error`, `packet_decode_error` | Separar fallos de ensamblado, descifrado, encabezado y decodificación. Los errores de E/S se registran como categorías. |
| `received type=0x48 op=Some(0) cipher_ready=…`, `handshake_ready`, `sent type=… op=…` | Identificar en qué conexión se decodificó el inicio del cifrado y si el escritor completó la escritura de cada respuesta. Los eventos de `0x2F` permiten correlacionar op `5` con el nuevo TCP y seguir ops `6` y `7`. |

Las operaciones aparecen solo tras decodificar correctamente el paquete. El registro de envío se escribe tras completar la escritura al TCP local. La recepción por el cliente se comprueba observando su siguiente operación. El modo registra únicamente conexiones con ambos extremos en loopback. Suprime los volcados, los detalles de errores de aplicación y la sonda de juego. El volumen de registros y la escritura síncrona a disco pueden alterar los tiempos observados. Acotar la recogida a los dos intentos y usar SQL de lectura para contrastar la posición guardada.

Con autorización para el cambio de proceso y con Archonia cerrado, usar el gestor local desde la raíz del repositorio. Los comandos operan sobre la instancia de Anchorville. El gestor comprueba el PID, los puertos y `@@datadir` de MariaDB antes de arrancar ArchCore. La opción de diagnóstico elige el binario aparte y escribe `archcore-handshake.log` y `archcore-handshake-error.log` en el directorio externo de la copia.

```powershell
$control = '.\.local\knight-spawn-test.ps1'
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $control -Action StopWorld
if ($LASTEXITCODE -ne 0) { throw 'The regular ArchCore process did not stop cleanly.' }
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $control -Action StartWorld -HandshakeDiagnostics
if ($LASTEXITCODE -ne 0) { throw 'The diagnostic ArchCore process did not become ready.' }
```

Confirmar que el log anuncia `diagnostics_enabled` y que se mantienen las escuchas en `127.0.0.1:11102` y `127.0.0.1:11108`. Abrir el cliente manualmente, completar el login ordinario, entrar con el Knight y pulsar «Cambiar personaje». Comparar las lecturas, op `0`, el estado de cifrado y op `6` entre los dos sockets. Si el nuevo cierra con `read_bytes=0`, el servidor no leyó datos en ese socket. Si registra bytes con cero tramas completas, revisar ese punto antes del descifrado.

Para recuperar la ejecución habitual tras cerrar el cliente y con la autorización correspondiente, detener el ArchCore instrumentado y arrancar sin la opción de diagnóstico. La misma MariaDB conserva la copia y el personaje entre ambos procesos.

```powershell
$control = '.\.local\knight-spawn-test.ps1'
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $control -Action StopWorld -HandshakeDiagnostics
if ($LASTEXITCODE -ne 0) { throw 'The diagnostic ArchCore process did not stop cleanly.' }
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $control -Action StartWorld
if ($LASTEXITCODE -ne 0) { throw 'The regular ArchCore process did not become ready.' }
```

Si el binario instrumentado termina durante el arranque, comprobar que ese proceso ha salido y que los dos puertos de juego están libres. En ese estado se puede arrancar directamente el binario habitual con `StartWorld`.

#### Resultado de la prueba instrumentada

El 22 de noviembre de 2026 se detuvo ordenadamente el ArchCore habitual y se inició solo el binario instrumentado sobre la misma copia de Anchorville. El nuevo proceso fue el único dueño de `127.0.0.1:11102` y `127.0.0.1:11108`. MariaDB mantuvo su proceso en `3337` y la configuración conservó la dirección de retorno explícita. El usuario abrió y cerró Archonia manualmente.

| Conexión | Secuencia observada |
| --- | --- |
| Login inicial `#1`, puerto de cliente `59279` | El servidor aceptó el TCP con `cipher_ready=false`. Recibió `0x48` op `0`, envió ops `6` y `1`, recibió op `2` y envió op `3` con el cifrado establecido. |
| Mundo `#2`, puerto de cliente `59281` | Completó el cifrado y recibió `0x2F` op `1` al pulsar «Cambiar personaje». El escritor completó el envío de op `5`. El socket se cerró unos dos segundos después. |
| Login nuevo `#3`, puerto de cliente `59286` | El mismo proceso de Archonia abrió el TCP correcto 93 ms después del envío registrado de op `5`. Al cerrarse, ArchCore informó `read_bytes=0` y `counted_packets=0`. |
| Login anterior `#1` durante el retorno | Trece milisegundos después de aceptar `#3`, recibió otro `0x48` op `0` con `cipher_ready=true`. El escritor envió ops `6` y `1` por `#1`. La siguiente trama, de 74 bytes, falló al descifrarse. Su operación queda indeterminada. No se completó un segundo handshake ni se decodificó `0x2F` op `6`. |

La traza confirma que Archonia envía el inicio del cifrado por el socket de login anterior aunque ya haya abierto uno nuevo. En `startup_encryption`, op `0` vuelve a preparar el cifrador de envío en esa conexión. La recepción seguía usando el cifrador anterior porque faltó el nuevo op `2`. La causa más probable es que el cliente conserva el socket o el estado de cifrado anterior durante el traspaso. La causa interna en el cliente y el contenido de la trama rechazada siguen abiertos. SQL confirmó que la clave de retorno venció sin consumirse y que el Knight conservó la última posición guardada. Los metadatos quedaron en `archcore-handshake.log` en el directorio externo de la copia.

La corrección mínima candidata es encolar el cierre del login anterior en `LoginConn::world_enter` inmediatamente después de `AUTH_KEY` y `WORLD_ENTER`, manteniendo la dirección de retorno explícita. La cola del escritor procesa esos envíos antes del cierre. El cambio se probaría primero en la copia de código con una instancia aislada y autorización específica. Comprobar primero que la entrada normal al mundo sigue funcionando. Después verificar que el nuevo socket recibe op `0`, completa Blowfish, procesa `0x2F` op `6` y devuelve la lista en el mismo cliente. Repetir el ciclo dos veces y contrastar el mismo CID y su posición. La prueba instrumentada actual solo cambió los registros. [Transferencia de login a mundo](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/login.rs#L552-L584) · [Cola de escritura y cierre](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/crates/archcore/src/net.rs#L259-L273)

#### Variante con cierre ordenado del login inicial

La segunda copia de trabajo está en `.local/archcore-return-close-trial`. Verificamos el SHA-256 de los 246 archivos copiados de la versión instrumentada antes de editar. `LoginConn::world_enter` encola `s.close()` después de `AUTH_KEY` y `WORLD_ENTER`. La traza del escritor registra sus códigos de operación, `FINISH_ENTER` y el cierre de escritura. Los eventos incluyen identificadores de conexión, puertos y tamaños, sin valores de claves ni contenido de paquetes.

Se compiló con Cargo `1.100.0`, `--offline --locked`, perfil `release` y destino `x86_64-pc-windows-msvc`. El SHA-256 del candidato es `bfb3f9002c92c10d25b30e6d571ef71f5a412d3e4d92b79cf7c5b5fa310819db`. Se volvieron a verificar los SHA-256 del ArchCore habitual, la primera versión instrumentada y el ejecutable de Archonia. El gestor local de la variante es `.local/archcore-return-close-trial/control.ps1`. Sus registros están en `run/` dentro de la misma copia, fuera de Git.

Tras reiniciar Windows, la comprobación de solo lectura confirmó que `auth.conf` y `world.conf` de Anchorville fijan el login y el mundo en `127.0.0.1:11102` y `127.0.0.1:11108`, que `ReturnToLogin.LoginAddress` sigue apuntando al login y que SOAP está desactivado. `mariadb.ini` apunta a `archonia-knight-spawn-movement\db` en `127.0.0.1:3337`. La sesión manual original usa `3327`. La comprobación previa encontró libres ambos puertos de MariaDB y los de juego. El manifiesto de parada limpia de Anchorville no estaba presente tras el reinicio.

Pasaron las 383 pruebas unitarias de ArchCore y las 11 de `archcore-net`. Una prueba TCP recibió `AUTH_KEY` y `WORLD_ENTER`, en ese orden, antes del fin de flujo. Para reanudar MariaDB se comparó la base original con su manifiesto y se registraron los SHA-256 de los 412 archivos de Anchorville antes del arranque. La consulta autenticada confirmó `@@datadir` y el puerto `3337`. El Knight de la copia tiene CID `1`, TID `96` y posición guardada `(-476683.375, 4313.16748046875, -55519.4609375)`. Se leyó la fila antes de arrancar ArchCore y la lectura quedó guardada en `run/knight-before.tsv`.

El candidato arrancó con un solo proceso de ArchCore para login y mundo y un solo proceso de MariaDB. Las tres escuchas eran de loopback y `3327` quedó libre. El simulador estableció Blowfish en ambos servicios sin autenticar ninguna cuenta. Las dos conexiones de esa sonda preceden a la prueba gráfica en `run/archcore-handshake.log`.

Archonia x64 parche `665` inició sesión y entró en Anchorville con el Knight. A las `19:11:01.212Z` el escritor de login `#3` completó `AUTH_KEY` (`0x03` op `11`) y `WORLD_ENTER` (`0x0D` op `8`) en ese orden y cerró la escritura. A las `19:11:01.427Z` terminó la sesión inicial de login. Mundo aceptó la conexión `#4` a las `19:11:01.450Z`, completó Blowfish y envió `FINISH_ENTER` a las `19:11:02.344Z`. El usuario confirmó que veía al Knight en el mundo.

En el primer intento de volver a la selección, mundo `#4` recibió `0x2F` op `1` y envió op `5` a las `19:11:50.280Z`. Login aceptó el nuevo TCP `#5` 83 ms después. En ese mismo socket recibió `0x48` op `0`, completó Blowfish a las `19:11:50.383Z` y decodificó `0x2F` op `6` a las `19:11:50.387Z`. Login respondió con `LOGIN_RESULT` (`0x0D` op `15`) dos milisegundos después. En `LoginConn::on_return`, esa respuesta corresponde al rechazo de la validación de retorno. La captura del usuario muestra que Archonia quedó en la pantalla de carga con el diálogo «Invalid account credentials.». En la traza faltaron el desafío `0x0D` op `0` y la confirmación `0x2F` op `7`.

La posición guardada después del intento coincidió con la inicial en los tres ejes para el CID `1`. La consulta de solo lectura también confirmó que la cuenta del Knight seguía teniendo una clave vigente después del rechazo. El código intenta limpiar ese campo en la fila seleccionada por el nombre de cuenta decodificado de op `6`, incluso cuando la comprobación de la clave falla. La clave vigente en la fila del Knight apunta a que la comparación SQL por nombre no encontró esa cuenta. La lectura del paquete exacto sigue pendiente. La trama de 90 bytes admite varias combinaciones de campos con el esquema actual debido al relleno Blowfish. La longitud de la trama por sí sola deja abierta la presencia del campo de cuenta.

Tras cerrar Archonia, se detuvieron ordenadamente ArchCore y MariaDB. El gestor archivó los logs de ArchCore en `run/archcore-stopped-17988.log` y `run/archcore-stopped-17988-error.log`. La consulta final del Knight, guardada en `run/knight-at-shutdown.tsv`, coincidió con la inicial. Se verificó el manifiesto de parada de los 409 archivos de Anchorville, el manifiesto de 408 archivos de la base manual original y que los puertos quedaron libres.

#### Comparación del campo de cuenta

En el login normal (`0x0D` op `1`), el decodificador entrega el campo `2` como 49 bytes. `LoginConn::user_login` toma la longitud del campo `3`, descifra esos bytes con RC4 usando el desafío de esa conexión y convierte el resultado de Windows-1252. La consulta de autenticación busca la cuenta por ese nombre y comprueba su contraseña. Mundo recibe el identificador de la cuenta durante la entrada y guarda la clave de retorno en la fila de ese identificador.

En el regreso (`0x2F` op `6`), el esquema también declara un campo `2` de 49 bytes, bajo una máscara de presencia. `LoginConn::on_return` lo lee como texto Windows-1252 hasta el primer cero, recorta los espacios y usa una cadena vacía si el campo falta. Lee la clave del campo `5`. Busca una fila que cumpla a la vez nombre, clave positiva y vigencia. La limpieza posterior usa el nombre recibido. El login envía el desafío RC4 solo si pasa el retorno. El simulador prepara op `6` con el nombre ya en texto, así que reproduce la expectativa del servidor. El formato real de Archonia `665` sigue por comprobar.

La copia temporal `.local/archcore-return-account-diagnostics` añade presencia y longitud del campo al primer login autenticado y al retorno. En el retorno, una consulta de lectura compara el nombre interpretado con la única cuenta que tenga vigente la clave recibida. La traza registra el resultado de la comparación o un valor indeterminado si falta una coincidencia única o falla la consulta diagnóstica. La traza funciona entre extremos de loopback y se conserva la lógica de autenticación. La compilación `--offline --locked` produjo el binario con SHA-256 `78034f9cf4c3eaed96cbe7a621dac620a9358555ca0b729e145da3188dda3977`. Pasaron 394 pruebas unitarias y la consulta de comparación pasó seis casos sintéticos en SQLite en memoria. El laboratorio permanece apagado y la traza aún requiere una prueba con MariaDB y Archonia.

#### Origen del campo en Archonia x64 parche 665

La inspección estática del ejecutable local con SHA-256 `e13603c37083aaa81e357a622f9cb99b32044f922d18441660c98d87290bb1a6` identificó el origen del campo. En la tabla de despacho del receptor `0x0D` (`0x140771418`), op `1` lleva a `0x140770EA6`. Esa rama toma el campo `2` de la respuesta del servidor y lo copia al búfer de cuenta de `AgcmLogin` (`+0x1794`). Al comenzar el retorno, `0x1406BC150` entrega ese mismo búfer a `0x1402F3470`. El constructor de `0x2F` op `6` comprueba que el texto empiece con un byte distinto de cero y pasa el búfer directamente al serializador como campo `2`, junto con la clave en el campo `5`. El constructor del esquema en `0x1402F29AB` declara un ancho de 49 bytes para el campo de cuenta. El flujo de construcción observado reutiliza el búfer de texto sin aplicarle RC4 en ese paso.

En `ad280a6`, la respuesta `0x0D` op `1` de ArchCore devuelve el búfer cifrado de la petición de login. Eso explica por qué el cliente puede entrar normalmente y luego reenviar como cuenta de retorno los bytes que leyó en esa respuesta. También explica que la consulta por nombre de op `6` pueda fallar mientras la clave de la cuenta correcta sigue vigente. La trama archivada de 90 bytes es compatible con los campos `0`, `2` y `5` del constructor y el relleno de Blowfish. La inspección identifica una causa concreta en el servidor. Queda pendiente confirmar en la interfaz que el ciclo completo funciona con la respuesta corregida.

La corrección está en `.local/archcore-return-compatibility`. La respuesta de login coloca el nombre canónico de la cuenta autenticada en el campo `2`. Op `6` sigue leyendo ese campo como texto y requiere un nombre presente con contenido, una clave positiva y la vigencia registrada para esa cuenta. El servidor bloquea la fila durante la comprobación y consume la clave válida dentro de la misma transacción. El desafío posterior queda vinculado al identificador de la cuenta de la clave, y `0x2F` op `7` se envía solo tras autenticarla con su contraseña. La transferencia al mundo conserva el cierre encolado después de `AUTH_KEY` y `WORLD_ENTER`.

#### Regresión automatizada del retorno

En Windows x64, la variante compiló con Cargo `1.100.0`, `--offline --locked` y el destino `x86_64-pc-windows-msvc`. Su SHA-256 es `fb787373897642f24577d56971ade71a73b39e2311a1ef5e418029293b18fa89`. Pasaron las 394 pruebas unitarias de ArchCore y `archcore-net` y la prueba de integración `tools::sim::return_regression::archonia_665_return_to_selection` contra MariaDB `11.4.14`.

La integración usa una base nueva en `127.0.0.1:3347` con dos cuentas y un Knight de prueba. El simulador reutiliza literalmente el campo `2` de la respuesta de login, como hace el ejecutable inspeccionado. Comprueba la autenticación inicial, `AUTH_KEY`, `WORLD_ENTER` y el fin de flujo TCP en ese orden. Entra al mundo en `127.0.0.1:12108`, recibe `FINISH_ENTER` y solicita el retorno. Cada socket nuevo de login en `127.0.0.1:12102` completa Blowfish antes de op `6`.

El campo canónico Windows-1252 con un carácter acentuado permitió el regreso. La prueba reprodujo el rechazo con los bytes del eco RC4 anterior y cubrió también campo ausente, vacío, espacios, UTF-16, otra cuenta y claves incorrectas, ausentes, negativas o caducadas. Dos conexiones presentaron la misma clave vigente y una sola recibió el desafío. En esa conexión se rechazaron las credenciales válidas de la segunda cuenta y una contraseña errónea de la cuenta esperada. La contraseña correcta produjo `0x2F` op `7`, volvió a listar el personaje y permitió entrar de nuevo con el mismo CID y posición.

Para repetir el ensayo instrumentado, usar `run-return-regression.ps1` de la copia aislada con `Start`, `Test` y `Stop` y el mismo nombre de ejecución nuevo en `-Run`. Se conservaron los logs en `return-fixture-compat-1` y la instancia desechable se apagó. Los manifiestos de 409 archivos de Anchorville y 408 de la sesión manual original coincidieron con sus huellas previas. La preparación para integrar las correcciones tiene su propio procedimiento reproducible. [Integración del retorno a selección](ARCHCORE_RETURN_INTEGRATION.md)

#### Validación gráfica del regreso a selección

El 22 de noviembre de 2026, el usuario confirmó que Archonia `665` volvió a mostrar la lista de personajes. Se usó el candidato instrumentado con ambas correcciones y SHA-256 `fb787373897642f24577d56971ade71a73b39e2311a1ef5e418029293b18fa89`. Solo estaban activos el ArchCore de Anchorville y su MariaDB en `3337`, ambos en loopback.

| Ciclo | Evidencia de login | Reentrada |
| --- | --- | --- |
| Primero | La sesión nueva `#5` completó Blowfish, recibió `0x2F` op `6`, confirmó que el campo de cuenta coincidía y envió op `7` a las `19:48:22.723Z`. Siguió la petición y el fin de la lista. | Mundo `#6` envió `FINISH_ENTER` a las `19:48:25.325Z`. |
| Segundo | La sesión nueva `#7` completó el mismo flujo y envió op `7` a las `19:48:31.838Z`. Siguió la petición y el fin de la lista. | Mundo `#8` envió `FINISH_ENTER` a las `19:48:36.707Z`. |

En las tres transferencias, el escritor completó `AUTH_KEY` y `WORLD_ENTER` antes de cerrar la escritura del login. La traza del ensayo no registró errores de descifrado ni respuestas de rechazo de login. Tras cerrar Archonia, se detuvieron ArchCore y MariaDB ordenadamente. La consulta final devolvió el CID `1` y la posición `(-475579.75, 4402.9248046875, -61020.890625)`. La posición inicial en la base era `(-476683.375, 4313.16748046875, -55519.4609375)`. La traza gráfica confirmó las reentradas. La verificación de las coordenadas de carga en cada reentrada se realizó con el personaje sintético de la regresión automatizada.

El archivo `archcore-stopped-11276.log` y los puntos de control de SQL se conservaron bajo `.local/archcore-return-compatibility/run/`. El manifiesto de la parada de Anchorville registró 409 archivos. Se verificaron las 408 huellas de la sesión manual original y quedaron libres los puertos del laboratorio.

### Recuperar el Knight de Anchorville

Reanudar la base existente en `archonia-knight-spawn-movement\db` con el `mariadb.ini` de esa copia si está detenida. Confirmar que MariaDB informa ese directorio en `@@datadir` y escucha en `127.0.0.1:3337`. Arrancar ArchCore con el directorio raíz y la configuración de la copia, apuntando a esa MariaDB, si los servicios de juego están detenidos. Abrir manualmente `Game\Archonia.exe`, entrar por el grupo `ArchCore` en `127.0.0.1:11102` y seleccionar el Knight existente con la cuenta de la prueba. Tras la validación gráfica quedaron guardados el CID `1` y el punto `(-475579.75, 4402.9248046875, -61020.890625)`. La sesión manual original se conserva por separado.

## Alternativa secundaria con ArchRust

1. Con autorización separada, revisar dependencias y scripts de compilación del pin de ArchRust. Compilar en Windows x64 con su `Cargo.lock` y registrar revisión, versión de herramientas y hash del binario propio. Preparar `--no-client` con rutas de paquetes vacías o auditadas. Confirmar primero que abre la ventana de login. La fase se puede detener ahí sin iniciar servicios ni escribir en MariaDB. [Compilación y comandos de ArchRust](https://github.com/BlaMacfly/ArchRust/blob/256888eb123063e21711bde98f9572c44fed5bee/README.en.md#L67-L85) · [Manifiesto Cargo](https://github.com/BlaMacfly/ArchRust/blob/256888eb123063e21711bde98f9572c44fed5bee/Cargo.toml)
2. Si abre la ventana y se autoriza el ensayo con persistencia, preparar una instancia desechable con la plantilla Knight ya comprobada, una cuenta temporal sin GM y los tres puertos aislados de la tabla anterior. Arrancar ArchCore fijado y confirmar las escuchas y la dirección anunciada. Introducir la cuenta desde la GUI sin guardar la contraseña. Registrar si aparecen la lista de personajes y la opción Knight antes de crear nada.
3. Crear o seleccionar el Knight. Contrastar la autenticación, el CID persistido, la transferencia y `FINISH_ENTER` con logs y registros desechables. Cerrar y reconectar para comprobar el mismo CID. Si la selección es viable pero el modelo o terreno quedan vacíos, registrar qué recurso falta y mantener ese hito como pendiente. Para dar la prueba gráfica por cumplida, registrar además una captura de un avatar visible sobre suelo propio o autorizado y un desplazamiento breve reflejado por el servidor. Las capturas y los logs deben excluir contraseñas y tokens de sesión.
4. Detener ambos servicios, comprobar los puertos libres y limpiar los datos de prueba de la instancia desechable.

El laboratorio habitual permaneció separado de los ensayos gráficos. Se conservaron los archivos originales del cliente y la base de la sesión manual. Los ensayos registrados usaron el ejecutable extraído del paquete directo, con las credenciales de prueba fuera del informe y de Git.
