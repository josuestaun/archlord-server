# Estabilidad del laboratorio EP8 y pruebas gráficas

Sesión del 23 de noviembre de 2026 en `feature/anchorville-npc-monster-spawns`. Se usaron ArchCore `ad280a6`, MariaDB `11.4.14` y la copia de Archonia x64 parche `665` en `.local/archonia-665-ui/Game`. Login, World y MariaDB escucharon en loopback en los puertos `12102`, `12108` y `3347`.

## Transferencia de Login a World

El tercer parche retrasa tres segundos el cierre del socket de Login tras encolar la transferencia y deja de atender solicitudes de aplicación en esa sesión. La traza del ensayo gráfico instrumentado registró el envío de la transferencia a las 15:51:22.159 UTC, la conexión a World 211 ms después y la clave inicial de World a las 15:51:23.471. Login cerró la escritura a las 15:51:25.164, cuando el cliente ya había entrado en World. World siguió recibiendo keepalives cada 15 segundos.

El laboratorio anterior reprodujo el aviso con la población desactivada y el socket de World en `ESTABLISHED`. En esta sesión, el binario de control con los dos primeros parches reprodujo el aviso con la misma copia del cliente, la misma cuenta y la misma MariaDB que la prueba con el cierre diferido. La captura `s48-baseline-WorldHud-20261123-161531-034.png` contiene el aviso. Queda por identificar con instrumentación del cliente el evento interno que lo muestra. [Parche y regresión](ARCHCORE_RETURN_INTEGRATION.md)

## Resultados

| Comprobación | Resultado y evidencia |
| --- | --- |
| Compilación, unidades e integración | Compilación Windows x64 sin red con los tres parches. Pasaron 382 pruebas de ArchCore y 11 de `archcore-net`. La regresión de transferencia y regreso a selección pasó aparte en una MariaDB nueva y desechable. El binario tiene SHA-256 `55f4bdc377ccd1d05795b176c18cf05e3eb1e6aa8bdc03debd07cfe6f81cb6cc`. |
| Arranque, credenciales temporales y primera entrada | El proceso aislado completó login y selección de AnchorKnight. Se observaron 300,4 segundos entre las primeras y últimas capturas clasificadas con HUD, sin aviso de reconexión durante el muestreo. Las capturas llevan el prefijo `session48-desktop-`. |
| Inventario de AnchorKnight | Se abrió con **I**. La captura muestra tres tipos de objetos en la bolsa y el personaje lleva la espada equipada. SQL confirmó cuatro filas de objetos. La comprobación nueva reconoció el título de la ventana en `s48-inventory-check-Inventory-20261123-155804-053.png`. |
| Movimiento y regreso a selección | La cámara y el personaje se desplazaron tras un clic en el terreno. Al volver a selección, SQL registró el mismo CID `1` y el paso de `(-475821.5, 4642.016, -66453.469)` a `(-476012.719, 4609.188, -67244.203)`. Nivel, XP, Gold y número de objetos coincidieron. |
| Segundo personaje | Tras volver a selección con el mismo proceso, AnchorProbe entró y mantuvo el HUD durante otros 301,53 segundos. El observador registró 68 muestras y un intervalo máximo de 4,734 segundos. Se abrió su inventario al finalizar. |
| Reinicio con binario recién compilado | Tras cerrar Archonia se reiniciaron Login y World con la compilación sin instrumentación. AnchorKnight volvió a entrar y mantuvo el HUD durante 301,03 segundos en 66 muestras, con un intervalo máximo de 4,748 segundos. Se verificaron la bolsa y el cierre gráfico. SQL devolvió las mismas coordenadas, CID, nivel, XP, Gold y número de objetos que después del movimiento. |
| NPC y servicio existente | Se vieron Lucy, Holly, Halo y Darryl. El clic en Darryl abrió su conversación y **Buy/Sell** mostró la tienda con catálogo, inventario y Gold de AnchorProbe. El cursor reconoció a Lucy y el clic a distancia quedó sin diálogo visible. |
| Compra con moneda de juego | AnchorProbe compró una poción por 10 Gold. La interfaz mostró 8 → 9 unidades en la bolsa y 970 → 960 Gold. Tras reiniciar World, MariaDB conservó el saldo y las nueve unidades se vieron al abrir de nuevo la bolsa. |
| Criatura renderizada | Se vio una gallina junto a Holly. MariaDB devolvió `Type=8` para Hen y los animales domésticos cercanos. ArchCore exige los bits `ATTACKABLE` y `TARGETABLE` para atacarlos. La gallina confirma que se renderiza fauna doméstica en Anchorville. [Regla y prueba de ArchCore](../server/archcore/crates/archcore/src/world/monsters.rs) |
| Exploración de Limelight Northern | AnchorProbe entró y se desplazó hasta la costa de un sector ya cargado que el cliente identifica como Limelight Northern. La base ubica cerca una Water Viper con los bits de objetivo y ataque. Los ensayos con clic y **Tab** dejaron pendiente confirmar su selección y el combate. El cliente se cerró y SQL confirmó la restauración de la posición de prueba. |

Los PNG y los resultados de solo lectura `before-move.tsv`, `after-move.tsv`, `after-purchase.tsv` y `after-restart.tsv` se conservan en `.local/`. La lectura SQL verificó el directorio, el puerto y el bind de la MariaDB desechable antes de consultar las dos filas de la cuenta de ensayo.

Los NPC, criaturas y mapas observados pertenecen a la carga local preexistente. El cambio de servidor y las herramientas de prueba funcionan con el pin y la copia gráfica indicados arriba.

## Repetir la prueba gráfica

En un escritorio interactivo de Windows, preparar la copia local de Archonia `665` a 1920 × 1080 y el escenario con los personajes desechables AnchorKnight y AnchorProbe. El ejecutor usa la copia en `.local/archonia-665-ui/Game` y lee la cuenta de prueba de `anchorville-665-test-account.txt` en la fixture local de Anchorville. Comprueba la huella del cliente y que `ArchoniaTest.ini` tenga un solo grupo en `127.0.0.1:12102`. Elegir un nombre nuevo en `-ArtifactRun` para compilar el capturador y guardar evidencia en un directorio vacío. Ejecutar desde la raíz del repositorio en un terminal de desarrollo x64 con el SDK de Windows. [Configuración del cliente](ARCHCORE_GRAPHICAL_CLIENT.md#conexión-al-laboratorio)

```powershell
$ui = '.\scripts\test-archonia-ui.ps1'
$artifacts = 'anchorville-smoke-1'
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $ui -Action Build -ArtifactRun $artifacts
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $ui -Action Launch -ArtifactRun $artifacts
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $ui -Action Enter -ArtifactRun $artifacts -Character AnchorKnight -Label knight -ObserveSeconds 300
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $ui -Action Inventory -ArtifactRun $artifacts -Label knight-inventory
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $ui -Action Return -ArtifactRun $artifacts -Label knight-return
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $ui -Action Reenter -ArtifactRun $artifacts -Character AnchorProbe -Label probe -ObserveSeconds 15
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $ui -Action Close -ArtifactRun $artifacts -Label probe-close
```

`Observe` permite volver a muestrear una sesión abierta. Un resumen correcto informa la duración, el número de muestras y el intervalo máximo entre ellas. `Click` recibe coordenadas del área cliente y admite `-RightButton`. `Snapshot` conserva la escena después de la acción. El capturador verifica el HWND y el PID. Los eventos de entrada requieren que la ventana comprobada tenga el foco.

El primer arranque dentro del entorno restringido abrió el proceso, pero Windows Graphics Capture devolvió `0x80070424`. La ejecución en el escritorio interactivo permitió capturar e introducir acciones. Las capturas archivadas comprobaron la detección del aviso de reconexión, el marco del menú de selección y la confirmación de salida. Los dos últimos se reconocen por rasgos visuales en escenas donde el OCR omitía el texto.

La arena iluminada de Limelight Northern reprodujo un falso positivo en la detección del menú. El detector comprueba ahora el contraste entre el marco y el interior. Las capturas verificaron el menú abierto y cerrado en esa escena y en Anchorville. Después del cambio, el cierre gráfico en la playa completó la confirmación y salió con código `0`.

## Cierre del hito

Se preparó una copia nueva de ArchCore desde `ad280a6` y se recompiló el capturador de Windows en `.local/archonia-665-ui/run-milestone48`. En la base gráfica ya provisionada, AnchorKnight completó 301,45 segundos de observación con 69 muestras, un intervalo máximo de 4,653 segundos y sin aviso de reconexión durante el muestreo. La prueba abrió su inventario, volvió a selección y entró con AnchorProbe. Se abrió su inventario y el cliente terminó con código `0`.

En una MariaDB nueva se repitió la regresión TCP de reconexión y regreso a selección. Pasaron también 382 pruebas unitarias de ArchCore y 11 de `archcore-net`. El importador cargó un NPC y un punto de criaturas sintéticos, descartó un NPC cuyo TID faltaba en el catálogo y un punto sin posición, y registró las tres etapas terminadas. La prueba comprobó las filas en MariaDB y dejó el registro en `.local/archcore-return-integration-milestone48/return-fixture-milestone48/`.

El cotejo SQL de solo lectura sobre la base desechable existente confirmó 23 NPC, 12 puntos de criaturas en la región `9` y tres etapas de importación terminadas. Las pruebas gráficas de Anchorville y Limelight Northern usan esa carga ya disponible. La preparación gráfica integral desde un catálogo real vacío sigue pendiente.

El overlay `prepare-anchorville-npcs.ps1` y el borrador histórico `ARCHCORE_ANCHORVILLE_SPAWNS.md` se conservan en el árbol de trabajo. El overlay experimental reintroduce dos colocaciones cuyos TID carecen de plantilla en la copia de Archonia `665`. La carga validada sigue usando las reglas del importador fijado. La reproducción desde una base vacía se comprueba con datos sintéticos mediante `TestImport`. [Regresión reproducible](ARCHCORE_RETURN_INTEGRATION.md#reproducción-local)
