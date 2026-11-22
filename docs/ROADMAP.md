# Hoja de ruta del proyecto

El primer objetivo es conseguir una sesión local de ArchLord EP8 jugable y estable en Windows con ArchCore y Archonia x64. Después se evaluarán adaptaciones hacia el episodio 3 de Codemasters, *Spirits Awakening* (2008–2009). La publicación se decidirá por separado.

| Fase | Alcance | Criterios de finalización |
| --- | --- | --- |
| 0. Base del repositorio | Inspeccionar Git, establecer las reglas de trabajo y documentar la arquitectura provisional y la investigación inicial. | Los cuatro archivos de base están presentes y las reglas de exclusión locales están verificadas. |
| 1. Viabilidad | Confirmar la compilación del cliente y la revisión del servidor para EP8. Revisar las licencias, la procedencia de los datos, la compatibilidad y las dependencias. | Registrar las revisiones, los recursos requeridos y sus usos permitidos, y un procedimiento de arranque local que pueda probarse. |
| 2. Prueba de concepto local | Configurar en un solo equipo la tecnología seleccionada con datos locales de prueba. Probar el arranque, el inicio de sesión, la creación o selección de un personaje y la entrada al mundo. | Desde una instalación local limpia, iniciar sesión, entrar en una zona, moverse, reconectar y comprobar el estado del personaje después de reiniciar el servidor. Verificar que los servicios del juego y la base de datos solo sean accesibles desde el propio equipo. |
| 3. Prueba de jugabilidad local | Comprobar que dos clientes locales puedan verse entre sí y validar un ciclo de combate, habilidad, experiencia y botín con la referencia elegida. Añadir comprobaciones específicas y documentar la configuración, los registros y las carencias conocidas. | Reproducir el escenario con cuentas de prueba y demostrar que la recompensa y el estado del personaje se conservan según lo previsto. |
| 4. Prueba privada, opcional | Preparar una prueba controlada si se aprueba. Revisar el acceso, el soporte de las dependencias, las copias de seguridad y su restauración, la monitorización y los costes de operación. | Demostrar que se pueden restaurar los datos y revertir los cambios, documentar los límites conocidos y obtener autorización para cualquier acceso externo. |
| 5. Operación pública, opcional | Revisar los derechos de alojamiento, uso de nombres y distribución de cada componente. Planificar la gestión del abuso, la privacidad, el soporte de las dependencias, la capacidad y la respuesta a incidentes. | Resolver los derechos y requisitos operativos aplicables, superar las comprobaciones previas al lanzamiento y obtener autorización explícita para publicar. |

El laboratorio EP8 completó la [compilación en Windows](ARCHCORE_WINDOWS_LAB.md), el [arranque con MariaDB](ARCHCORE_LOCAL_SERVER.md) y la [creación de un Knight y entrada gráfica al mundo](ARCHCORE_GRAPHICAL_CLIENT.md#sesión-manual-persistente-del-parche-665). En una copia aislada también se comprobó [el movimiento por clic cerca de Anchorville y la recuperación de la posición al abrir de nuevo Archonia](ARCHCORE_GRAPHICAL_CLIENT.md#ensayo-de-aparición-en-anchorville). En la fase 2 queda por reproducir el recorrido desde una instalación limpia y verificar el punto guardado tras reiniciar el servidor.

La [validación gráfica del regreso a selección con Archonia x64 parche 665](ARCHCORE_GRAPHICAL_CLIENT.md#validación-gráfica-del-regreso-a-selección) completó dos ciclos en la misma instancia del cliente. Los [parches y la regresión del servidor](ARCHCORE_RETURN_INTEGRATION.md) se integraron en `develop` mediante el PR #12 sobre el pin actual. La [viabilidad técnica de EP3](EP3_SERVER_FEASIBILITY.md) recoge el estado de la referencia clásica.

## Próximos hitos de EP8

La [auditoría de jugabilidad](ARCHCORE_GAMEPLAY_AUDIT.md) identificó los catálogos vacíos de Anchorville y comprobó por TCP un ciclo sintético de diálogo, combate, reaparición, experiencia y Gold. Para cerrar la fase 2 y arrancar la fase 3, el primer objetivo es reproducir la sesión desde una MariaDB limpia y mostrar **un NPC y un monstruo en Anchorville** con Archonia `665`. Validar sus apariciones, abrir el diálogo y comprobar el punto guardado del personaje de prueba tras reiniciar World. [Criterios del primer escenario](ARCHCORE_GAMEPLAY_AUDIT.md#primer-objetivo-para-la-siguiente-rama)

La fase 3 sigue este orden y reutiliza el código y los simuladores del pin donde cubran el caso.

1. Validar visibilidad y terreno con el NPC y el monstruo.
2. Validar ataque, represalia, muerte y respawn con un segundo cliente local para observar sincronización.
3. Validar experiencia, subida de nivel, Gold y recogida de un objeto con persistencia.
4. Validar el inventario, un equipamiento, una skill y un buff.
5. Completar una compra y venta y una misión corta antes de ampliar catálogos y servicios.
