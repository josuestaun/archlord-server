# Integración del regreso a selección de ArchCore

Propuesta del 22 de noviembre de 2026. Archonia x64 parche `665` completó dos regresos a selección y dos reentradas con el candidato instrumentado. El repositorio principal fija ArchCore en `ad280a6efc069526fc58445e5397d52a0e809500` mediante el gitlink de `server/archcore`. Este pin es la base de los parches locales. [Validación gráfica](ARCHCORE_GRAPHICAL_CLIENT.md#validación-gráfica-del-regreso-a-selección)

## Cambios preparados

| Parche | Alcance |
| --- | --- |
| [`0001` de login](../server/patches/archcore/0001-fix-character-selection-return.patch) | Encola el cierre después de `AUTH_KEY` y `WORLD_ENTER`. Devuelve el nombre canónico en la respuesta `USER_LOGIN`, que Archonia reutiliza en op `6`. Exige nombre con contenido y clave vigente, la consume en una transacción y vincula la reautenticación a la misma cuenta. |
| [`0002` de regresión](../server/patches/archcore/0002-test-character-selection-return.patch) | Verifica los paquetes recibidos, su orden y el fin de flujo TCP. Usa el campo de cuenta de la respuesta y cubre el regreso correcto, el eco RC4 anterior, las representaciones inválidas, el uso único, la caducidad y la reautenticación. |

El parche funcional modifica únicamente `crates/archcore/src/login.rs`. Reutiliza la cola de escritura de ArchCore. La instrumentación temporal forma parte del binario observado en la prueba gráfica y queda fuera de los parches. Los parches tampoco necesitan cambios de esquema ni recursos de Archonia.

## Reproducción local

El [ejecutor de pruebas](../scripts/test-archcore-character-return.ps1) usa PowerShell 5.1, Git para Windows `2.51` o posterior, Rust estable x64 con MSVC y la distribución autorizada de MariaDB `11.4.14`. Antes de una primera ejecución, materializar el submódulo mediante el inicializador selectivo y preparar la caché de Cargo con el `Cargo.lock` fijado. El procedimiento de Windows documenta MSVC, el SDK y el comando `cargo fetch --locked` para una caché vacía. [Inicialización selectiva](ARCHCORE_LOCAL_SERVER.md#inicializar-después-de-clonar) · [Dependencias y caché de Cargo](ARCHCORE_WINDOWS_LAB.md#compilación-y-verificación) · [Distribución de MariaDB](ARCHCORE_LOCAL_SERVER.md#mariadb-y-migraciones)

`Prepare` exige que el gitlink y el checkout limpio coincidan con el pin, copia los archivos revisados a `.local/archcore-return-integration-<run>` y aplica los parches allí. Git conserva LF en los parches mediante `.gitattributes` para que `git apply` funcione también con la configuración habitual de Windows. `Build` compila y ejecuta las pruebas unitarias con `--offline --locked`. Elegir un valor nuevo de `-Run` para cada base de pruebas.

```powershell
$runner = '.\scripts\test-archcore-character-return.ps1'
$trialName = 'return-1'
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $runner -Action Prepare -Run $trialName
if ($LASTEXITCODE -ne 0) { throw 'Could not prepare the pinned source.' }
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $runner -Action Build -Run $trialName
if ($LASTEXITCODE -ne 0) { throw 'Could not build and test the patched source.' }
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $runner -Action Start -Run $trialName
if ($LASTEXITCODE -ne 0) { throw 'Could not start the disposable database.' }
try {
    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $runner -Action Test -Run $trialName
    if ($LASTEXITCODE -ne 0) { throw 'The return integration test failed.' }
} finally {
    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $runner -Action Stop -Run $trialName
    if ($LASTEXITCODE -ne 0) { throw 'The disposable database did not stop cleanly.' }
}
```

`Start` crea una base nueva en `127.0.0.1:3347`. `Test` valida la ruta de datos, genera contraseñas desechables y levanta login y mundo dentro de la prueba en `12102` y `12108`, exclusivamente en loopback. `Stop` conserva la base desechable y los registros. Si MariaDB está en otra ruta, pasar `-MariaDbBin` a `Start`, `Test` y `Stop`. Las bases persistentes permanecen fuera de ese recorrido.

Fuera de la regresión, el binario corregido está en `.local/archcore-return-integration-<run>/target/x86_64-pc-windows-msvc/release/archcore.exe`. Para usarlo en el laboratorio local administrado, pasar esa ruta a `-ArchCoreExe` en sus controles. El `world.conf` de esa instancia debe tener `ReturnToLogin.LoginAddress` con su dirección de login en loopback. La regresión ya configura su propia dirección de retorno. [Controles del laboratorio y selección de ejecutable](ARCHCORE_LOCAL_SERVER.md#controles-desde-vs-code-y-powershell)

La ejecución `return-1` repitió el procedimiento anterior desde una copia nueva del pin. Pasaron 382 pruebas unitarias de ArchCore, 11 de `archcore-net` y la regresión de integración con MariaDB. La regresión comprobó la lista y la reentrada con el mismo CID y las mismas coordenadas sintéticas. El binario compilado en esa ejecución tiene SHA-256 `7bd85e9990230e49e1aba264efdd5eeab4134aa93d0d9667f837ccdbf3246de1`. La base desechable se apagó y los puertos quedaron libres. La exportación del índice con `core.autocrlf=true` conservó los parches y la licencia byte por byte, y los parches exportados pasaron `git apply --check`. La prueba gráfica usó el binario instrumentado. La regresión ejecutó las funciones del servidor limpio dentro del proceso de pruebas.

## Licencia y procedencia

- El manifiesto del pin local declara `GPL-3.0-or-later`. Los dos parches indican el origen, la fecha de modificación y la licencia. Su directorio incluye una copia literal de la licencia del pin. Al distribuir una versión modificada, se conservan los avisos y se marcan las modificaciones y su fecha. Para distribuir un binario hay que ofrecer el código fuente correspondiente de esa versión, incluidos los cambios y los scripts necesarios según la modalidad de distribución. La mera agregación con obras independientes tiene un tratamiento distinto en la sección 5. [Licencia incluida](../server/patches/archcore/COPYING) · [GPLv3, secciones 1, 2, 4, 5, 6 y 14](https://www.gnu.org/licenses/gpl-3.0.html)
- El mantenedor indica que upstream incluye tablas del servidor y un mapa de EP8 bajo `data/server-ini`. La procedencia y los derechos de esos datos, de los recursos de Archonia y de cualquier contenido futuro de EP3 se verifican por separado. Antes de publicar un repositorio derivado, revisar también el historial que quedaría accesible. Un checkout parcial limita las descargas locales, pero publicar un commit hace accesible el historial que lo precede en el repositorio de destino. [Inventario descrito por el mantenedor](https://github.com/BlaMacfly/ArchCore#quick-start) · [Visibilidad e historial de los forks](https://docs.github.com/en/pull-requests/reference/forks#visibility-of-forks)

## Integración recomendada

1. Usar los parches y su prueba para revisión local. Cuando se autorice el trabajo externo, contrastarlos con la revisión vigente que se vaya a proponer a upstream. Si upstream integra las correcciones, fijar su commit y retirar la aplicación local de los parches cuando pase la regresión con ese pin.
2. Mantener una derivación propia si las adaptaciones de EP3 requieren cambios acumulativos o si upstream no absorbe este arreglo. Conservar una línea EP8 probada y abrir la línea de EP3 desde ella. Identificar el servidor original como `upstream` y el repositorio propio como `origin`, e incorporar las actualizaciones upstream en lotes que pasen la regresión EP8. Un fork nativo de GitHub de ArchCore sería público. Si se requiere acceso restringido o si el historial incluye datos sin procedencia verificada, evaluar un repositorio independiente cuyo árbol e historial publicados incluyan solo materiales revisados, con su licencia, atribución y revisión de origen. [Visibilidad de forks de GitHub](https://docs.github.com/en/pull-requests/reference/forks#visibility-of-forks)
3. Cuando exista un destino aprobado y el commit del servidor sea accesible para los colaboradores, preparar en la rama de ArchLord el gitlink a ese SHA exacto. Si cambia el origen, actualizar también `.gitmodules` y la URL permitida de `scripts/initialize-archcore-source.ps1`. Comprobar la sincronización de los checkouts existentes y una inicialización limpia. Integrar en `develop` mediante el flujo del proyecto. [Gitlinks y submódulos](https://git-scm.com/docs/gitsubmodules) · [Sincronización de submódulos](https://git-scm.com/docs/git-submodule) · [Flujo del proyecto](GIT_WORKFLOW.md)

Para la revisión, separar en el repositorio del servidor `fix(login): restore character selection after world handoff` y `test(login): exercise character selection return over TCP`. En el repositorio padre, el cambio de puntero puede usar `build(archcore): pin validated character return fix`.

Los riesgos técnicos son el cambio de semántica del campo de cuenta para clientes distintos de Archonia `665`, la caducidad o el acceso al SHA del submódulo y el esfuerzo de volver a aplicar los cambios en cada avance upstream. La regresión mitiga el riesgo del protocolo conocido. Una inicialización limpia verifica el acceso al SHA, y una línea EP8 separada permite medir cada cambio de EP3 contra una base jugable.
