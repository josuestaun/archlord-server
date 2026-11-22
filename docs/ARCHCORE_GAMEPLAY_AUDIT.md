# Auditoría de jugabilidad de ArchCore EP8

## Resumen ejecutivo

Revisión del 22 de noviembre de 2026. Servidor ArchCore `ad280a6efc069526fc58445e5397d52a0e809500` con los [parches de regreso a selección](ARCHCORE_RETURN_INTEGRATION.md), cliente Archonia x64 `665` y MariaDB `11.4.14`. Los diez sistemas auditados tienen código aprovechable. Esta cobertura por familias no permite calcular un porcentaje de jugabilidad, fidelidad a EP8 o compatibilidad gráfica.

La ruta gráfica más avanzada comprende creación del personaje, entrada, movimiento y regreso a selección. Una prueba local por TCP comprobó que ArchCore anuncia un NPC y un monstruo, permite dialogar, resuelve un golpe y el ciclo de muerte y reaparición del monstruo, y guarda la experiencia, la subida de nivel y el Gold recogido. Los catálogos y spawns de Anchorville están vacíos. El primer trabajo es poblar y validar un tramo pequeño del mapa con un NPC y un monstruo usando datos con procedencia comprobada.

La prueba gráfica acumulada con `665` cubre autenticación, creación y selección de un Knight, escena, desplazamiento por clic con velocidades de ensayo, posición recuperada y dos regresos a selección. El alcance gráfico de esta auditoría procede de esas sesiones previas y de un inventario local de archivos. [Sesión inicial y ensayo de aparición](ARCHCORE_GRAPHICAL_CLIENT.md#ensayo-de-aparición-en-anchorville) · [validación gráfica del regreso](ARCHCORE_GRAPHICAL_CLIENT.md#validación-gráfica-del-regreso-a-selección)

## Estado comparado

**Implementado y verificado** se aplica solo al comportamiento observado, al nivel de prueba indicado. **Implementado sin verificar** identifica rutas presentes cuyo recorrido se debe ejecutar. **Parcial** indica una carencia concreta. **Bloqueado por datos** se refiere al laboratorio Anchorville. **No implementado** se aplica a una función concreta sin una ruta funcional identificada. La dificultad estima el trabajo para verificar un primer caso con `665` una vez disponibles las entradas autorizadas.

| Sistema | Rust y evidencia automatizada | Anchorville y Archonia 665 | Dificultad |
| --- | --- | --- | --- |
| A. NPC | Implementado y verificado con vista y permiso de diálogo por TCP. Tiendas y servicios implementados sin verificar aquí como recorridos completos. | Bloqueado por datos. Visibilidad, interacción y tienda pendientes en el cliente. | Baja para mostrar un NPC, media para sus servicios. |
| B. Monstruos | Implementado y verificado en colocación, vista, muerte, retirada y respawn. IA y persecución tienen lógica y unidades. | Bloqueado por spawns, estadísticas y perfiles de IA. Modelos y movimiento pendientes en el cliente. | Media. |
| C. Combate | Implementado y verificado en cálculos físicos y elementales, golpe básico y muerte del mob. Muerte y resurrección del jugador implementadas sin verificar aquí como recorrido. | Bloqueado para PvE por falta de objetivos. Selección, animaciones y daños pendientes en el cliente. | Media para un ataque básico, alta para balance y variantes. |
| D. Experiencia y niveles | Implementado y verificado en el cálculo de umbrales y persistencia de una recompensa con subida de nivel. | Bloqueado por curva y crecimiento vacíos. Barra y aviso de nivel pendientes en el cliente. | Media. |
| E. Gold | Implementado y verificado en la generación, recogida y persistencia por TCP y SQL. Comercio, banco y transferencias implementados. | Bloqueado el circuito de obtención y gasto por falta de mobs, objetos y tiendas. UI pendiente. | Media. |
| F. Drops y loot | Implementado y verificado con tiradas, cantidades y reservas en unidades y Gold en suelo por TCP. Ruta de recogida de objetos y actualización de inventario presente. | Bloqueado el botín de objetos por falta de catálogo y tablas. Modelo en el suelo y recogida pendientes en el cliente. | Media. |
| G. Inventario y equipamiento | Implementado y verificado en lógica de colocación y factores. Existe carga, movimiento, consumo, equipamiento y guardado. | Bloqueado el circuito con objetos por falta de catálogo. Inventario completo, equipamiento y apariencia pendientes en `665`. | Media. |
| H. Skills y buffs | Implementado y verificado en cálculos de coste, relanzamiento y efectos. Aprendizaje y combate con skills implementados sin verificar como ciclo completo. Cobertura parcial del catálogo. | Bloqueado por catálogo vacío. Iconos, animación, sincronización de efectos y persistencia de una habilidad concreta pendientes. | Alta para cobertura amplia. |
| I. Quests | Parcial. Motor de ofertas, progreso, recompensas y diario con comprobaciones unitarias. Catálogos y objetivos dependientes de la edición. | Bloqueado por datos. Lista, seguimiento y entrega pendientes con `665`. | Alta para una cadena coherente. |
| J. Personajes y estadísticas | Implementado y verificado para un Knight, cálculo aislado de factores y guardado de posición. | Verificado gráficamente para creación, selección, entrada, posición y regreso. Resto de plantillas y crecimiento bloqueados por datos. | Baja para el Knight, media para ampliar clases. |

## Inventario funcional

Las rutas Rust citadas en esta sección son relativas a `server/archcore/crates/archcore/src`. Los [esquemas base de personajes](../server/archcore/sql/002_characters.sql) y de [mundo](../server/archcore/sql/003_world.sql) se complementan con las [migraciones incrementales](../server/archcore/sql/migrations).

### A. NPC

`world/npcs.rs` carga `npc_spawn`, indexa por CID, lee el listado ordenado de parámetros `Function` y arma una vista con TID, nombre, orientación y eventos. `world/mod.rs::send_nearby_npcs` añade o retira NPC al cambiar la visibilidad por sector. `world/npc_events.rs::on_dialog` resuelve el evento, valida alcance y devuelve un permiso de diálogo. Archonia aporta su texto y modelo, por lo que recibir el permiso permite probar el servidor aunque falte comprobar la ventana. Las pruebas unitarias decodifican la vista de un NPC y verifican la resolución por CID o evento.

`world/npc_trade.rs::on_packet`, `buy` y `sell` usan `npc_trade_list` e `item_data`, `characters.money` y `character_items`. Hay módulos separados para banco, teletransporte, reparación, conversión y maestro de habilidades. Cada uno requiere su función y parámetros en `npc.ini`, el TID visible en cliente y, cuando corresponda, su catálogo. Empezar con un NPC de diálogo. Agregar una tienda con un único objeto después de comprobar la vista y el clic. [Código de NPC](../server/archcore/crates/archcore/src/world/npcs.rs) · [eventos](../server/archcore/crates/archcore/src/world/npc_events.rs) · [comercio](../server/archcore/crates/archcore/src/world/npc_trade.rs)

### B. Monstruos

`MonsterRegistry::load` y `MonsterStats::from_data` relacionan `monster_spawn` con `character_data_table` por TID. `character_template` aporta datos como `HitRange`, `monster_ai` describe acciones por `ai_tid` y el mapa filtra la colocación bloqueada. `spawn_point` aplica cantidad, densidad, dispersión y posición. `world/ai.rs`, `monster_skills.rs`, `ai_kin.rs` y `combat.rs` contienen patrulla, detección, agresividad, persecución, retorno, represalias, habilidades y ciclo de muerte, retirada del cadáver y reaparición. Las unidades comprueban colocación reproducible, zonas bloqueadas, atributos y vista optimizada. Sigue pendiente contrastar una patrulla y una persecución en el terreno de Anchorville con `665`.

El primer spawn debe apuntar a un único TID que `665` pueda representar, con coordenadas en superficie, atributos de HP y movimiento, flags `TARGETABLE` y `ATTACKABLE` para el siguiente hito y un plazo de reaparición explícito. Registrar cuántas criaturas carga World y cuántas anuncia cerca del personaje. [Registro de monstruos](../server/archcore/crates/archcore/src/world/monsters.rs) · [IA](../server/archcore/crates/archcore/src/world/ai.rs)

### C. Combate

`world/combat.rs::on_action` valida estado y objetivo. Su ciclo `step` usa posición, alcance, velocidad y condiciones del atacante para resolver golpes. `hit_chance`, `strike`, `physical_hit`, `player_guard`, `spirit_hits` y los modificadores de `effects.rs` cubren precisión, defensa, evasión, bloqueo, crítico y resistencias físicas o elementales. El cálculo mágico y los efectos de habilidad pasan por `skills.rs`. `kill` marca la muerte del monstruo y activa recompensas, botín y progreso de quests. La ruta de jugador incluye actualización de HP y MP, muerte y resurrección. El mapa y los puntos de resurrección afectan al destino. Las unidades prueban fórmulas y límites. Falta probar contra `665` la selección, el golpe, la represalia, la muerte del jugador y las animaciones.

Comprobar primero un golpe reproducible entre Knight y mob con estadísticas conocidas. Luego añadir una represalia, observar los HP en ambos extremos y ejecutar la muerte y resurrección del jugador en una base desechable. [Resolución de combate](../server/archcore/crates/archcore/src/world/combat.rs) · [efectos](../server/archcore/crates/archcore/src/world/effects.rs)

### D. Experiencia y niveles

`world/combat.rs::kill` parte de `Exp` del monstruo y aplica el multiplicador `exp`, reparto de grupo y bonificaciones aplicables. `reward` llama a `gain_exp` con `level_exp`, vuelve a calcular estadísticas y puntos de habilidad y actualiza `characters.level` y `exp`. `growup_factor` aporta crecimiento por plantilla. `gain_exp` conserva la experiencia sobrante y espera un umbral positivo para subir de nivel. Una curva vacía permite acumular XP sin subir de nivel. Las unidades cubren umbrales y progresión. Validar un único umbral conocido, el recálculo de atributos y la recuperación tras reconexión y reinicio.

El importador combina las tablas EP8 de niveles 1 a 100 con el complemento del cliente en su ruta normal. `--webzen` es una ruta de datos alternativa con su propia curva hasta 121 según el código del pin. Elegir y etiquetar una fuente antes de fijar el balance. [Recompensa y curva](../server/archcore/crates/archcore/src/world/combat.rs) · [importación](../server/archcore/crates/archcore/src/tools/import.rs)

### E. Gold y economía

El monedero se guarda en `characters.money`, separado de saldo bancario y de Cash. `world/loot.rs` genera Gold por `Geld_Min`, `Geld_Max`, tasa `gold` y bonificaciones. La recogida acredita el monedero. `npc_trade.rs` valida existencias, espacio, precio y fondos en compras y ventas. `trade.rs` y `bank.rs` contienen las rutas de transferencia entre jugadores y depósito, con cambios de saldo y de objetos persistidos. Las unidades comprueban tasas y planes de pago. Las transferencias y su comportamiento concurrente requieren una prueba propia con dos cuentas. Probar saldo después de matar y recoger, antes de introducir un único precio de compra y venta. [Gold y recogida](../server/archcore/crates/archcore/src/world/loot.rs) · [intercambio](../server/archcore/crates/archcore/src/world/trade.rs) · [banco](../server/archcore/crates/archcore/src/world/bank.rs)

### F. Drops y loot

`world/loot.rs` carga `monster_drop`, `drop_group`, `drop_rank_rate` y el catálogo, y aplica probabilidades, cantidades, tasa `drop` y reglas de creación de objetos. `on_kill` publica el botín en el suelo. La recogida verifica proximidad, reserva y capacidad del inventario. El botín en el suelo caduca en memoria. Los ítems recogidos se guardan en `character_items`. Las unidades prueban tiradas, propiedad y límites. Para objetos, probar primero una tirada controlada de un TID conocido, dos cuentas para observar la reserva y un inventario sin hueco para comprobar el rechazo. [Generación, sincronización y recogida](../server/archcore/crates/archcore/src/world/loot.rs)

### G. Inventario y equipamiento

`world/items.rs` gestiona instancias, distribución en cuadrícula, pilas, movimientos y actualizaciones. `world/equipment.rs::on_item_update` comprueba estado, propiedad, slot y restricciones. `recompute_factors` recompone estadísticas con el equipo, sus opciones y otros modificadores. La capacidad depende de la capa y del tamaño del objeto, y hay almacenamiento separado para banco y otros tipos de bolsa. `item_data` e `item_template` aportan datos de objeto y presentación. `character_items` conserva posición, cantidad y durabilidad, con ampliaciones para opciones y conversiones. Se comprobó lógica aislada de objetos y factores. Hace falta observar un objeto tras recogerlo, moverlo, equiparlo y reconectar, comprobando un rechazo de nivel o clase y la apariencia en `665`. [Instancias de objetos](../server/archcore/crates/archcore/src/world/items.rs) · [equipamiento](../server/archcore/crates/archcore/src/world/equipment.rs)

### H. Skills y buffs

`world/skills.rs::SkillCatalog::load` lee `skill_template`, `skill_spec`, `skill_level` y `skill_mastery`. `on_master_packet`, `learn` y `refresh_points` gestionan aprendizaje y puntos. Las rutas de lanzamiento usan requisitos de clase y nivel, maná, posición, objetivo y relanzamiento. `effects.rs` compone buffs y debuffs, aplica modificadores y retira efectos vencidos. Las habilidades aprendidas se cargan y guardan en `character_skills`. La duración y recuperación de efectos activos se deben probar por tipo con el ciclo de entrada, salida y reinicio. Las unidades cubren coste, relanzamiento y efectos, entre otras reglas. La cobertura de cada skill, de maestrías y de los efectos propios de Archonia es parcial hasta ejecutar casos representativos por categoría.

Empezar con una habilidad del Knight y un buff con duración fija. Verificar coste de MP, segundo lanzamiento rechazado durante el cooldown, actualización al expirar, habilidad aprendida tras reconectar y animación con los recursos de `665`. [Habilidades](../server/archcore/crates/archcore/src/world/skills.rs) · [efectos](../server/archcore/crates/archcore/src/world/effects.rs)

### I. Quests

`world/quests.rs` carga `quest_template`, `quest_group` y `quest_object`. `on_event`, `accept`, `on_kill`, `gather` y `complete` relacionan oferta del NPC, requisitos, objetivos de muerte o recogida, diario, entrega y elección de recompensa. `character_quests` guarda progreso. Hay tests aislados de requisitos y recompensas y simuladores para misiones con NPC y objetos. El despachador del pin trata las operaciones enumeradas en `on_packet` y registra las demás como no gestionadas. La compatibilidad de un catálogo de Webzen con el diario y los textos de `665` depende de la importación y exige prueba propia. Los modos exclusivos de Archonia que el mantenedor excluye, como rifts y pase de batalla, quedan fuera de la ruta funcional encontrada en el pin.

Probar primero una misión de ofrecer, matar un monstruo y entregar, con el mismo TID de NPC y mob del primer escenario y una recompensa pequeña. Revisar sincronización de progreso después de reconectar y evitar mezclar ediciones al seleccionar textos y objetivos. [Servidor de misiones](../server/archcore/crates/archcore/src/world/quests.rs) · [alcance de episodios en el pin](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-Episode.md)

### J. Personajes y estadísticas

`login.rs` y `character.rs` manejan alta, pertenencia a cuenta, raza, clase, plantilla y factores. `character_template`, `character_data_table`, `growup_factor` y `login_char_pos` definen los datos de la clase, el crecimiento y el punto inicial. `world/equipment.rs::recompute_factors` integra equipo y efectos. `world/recovery.rs` aplica regeneración y temporizadores de combate. `world/presence.rs::save` y su autosave escriben la posición. La tabla `characters` conserva el personaje y su progreso, mientras las tablas hijas almacenan objetos, habilidades y diario. El laboratorio solo aporta la fila de modelo del Knight TID `96`, con velocidades de prueba, y un personaje. Probar con otro Knight de ensayo desde una instalación limpia, comprobar HP y MP antes y después del combate y verificar su estado tras reiniciar. Ampliar a otras clases con datos de creación y apariencia autorizados. [Login](../server/archcore/crates/archcore/src/login.rs) · [factores](../server/archcore/crates/archcore/src/character.rs) · [guardado de posición](../server/archcore/crates/archcore/src/world/presence.rs)

## Datos de Anchorville y MariaDB

Se inventariaron 98 tablas mediante `information_schema` y `COUNT(*)` en una transacción `READ ONLY` sobre una copia en frío de Anchorville. La copia escuchó en `127.0.0.1:3357` y se detuvo al terminar. Los 409 archivos de datos del laboratorio original conservaron los hashes de su manifiesto de apagado. Los resultados describen la instancia de Anchorville, preparada para MariaDB `3337`, login `11102` y mundo `11108` en el último ensayo gráfico. La prueba sintética se ejecutó en otra base creada desde cero. [Configuración y validación de la instancia gráfica](ARCHCORE_GRAPHICAL_CLIENT.md#validación-gráfica-del-regreso-a-selección)

| Esquema y grupo | Tablas inspeccionadas | Filas observadas |
| --- | --- | --- |
| `archcore_auth` | `account`, `server_group`, `world`, `account_banned` | 1 por catálogo activo y 0 prohibiciones. |
| `archcore_characters` | `characters`, `account_bank` | 1 Knight, CID `1`, y 1 registro bancario. |
| Estado de juego | `character_items`, `character_skills`, `character_quests`, `character_quickbelt`, `character_titles` | 0 en cada una. |
| NPC y tienda | `npc_spawn`, `npc_trade_list` | 0 en cada una. |
| Modelos y progresión | `character_data_table`, `character_template`, `growup_factor`, `level_exp`, `login_char_pos` | 1 fila de datos para TID `96` en `character_data_table`. Velocidades de ensayo `5000/6000`. Las demás están vacías. |
| Monstruos e IA | `monster_spawn`, `monster_ai` | 0 en cada una. |
| Objetos y botín | `item_data`, `item_template`, `monster_drop`, `drop_group`, `drop_rank_rate` | 0 en cada una. |
| Skills | `skill_template`, `skill_spec`, `skill_level`, `skill_mastery` | 0 en cada una. |
| Misiones | `quest_template`, `quest_group`, `quest_object` | 0 en cada una. |
| Terreno y regiones | `map_height`, `map_segment`, `region_template`, `region_glossary`, `resurrection_point`, `teleport_point` | 0 en cada una. |
| Importaciones y textos | `import_run`, `client_table`, `language`, `localized_text` | 11 idiomas. Las demás están vacías. |
| `archcore_logs` | `log_anomaly`, `log_auction`, `log_bank`, `log_gm`, `log_shop`, `log_trade` | 0 en cada una. |
| Migraciones | `schema_migrations` en auth, personajes, mundo y logs | 4, 28, 23 y 4 registros, respectivamente. Son historial de esquema. |

Las comprobaciones de vecindad a 3000 unidades del punto guardado también devolvieron cero NPC y monstruos. La geometría del cliente puede mostrar el pueblo aunque las tablas de altura, regiones y segmentos de colisión del servidor estén vacías. Por ello, el desplazamiento observado no valida suelo, obstáculos ni reaparición. `003_world.sql` crea los catálogos base, las migraciones añaden `monster_ai`, `skill_mastery`, `quest_object` y otros sistemas, y `002_characters.sql` con sus migraciones define el estado de personaje. [Esquema de mundo](../server/archcore/sql/003_world.sql) · [IA y maestrías](../server/archcore/sql/migrations/world/202610251200_ia_des_monstres_et_maitrises.sql) · [objetos de misión](../server/archcore/sql/migrations/world/202611082200_quetes_des_objets.sql)

### Origen de los datos y orden de importación

| Entrada | Qué aporta a la importación | Disponibilidad observada |
| --- | --- | --- |
| `data/server-ini` o `--server` | `npc.ini`, `npctradelist.txt`, `characterdatatable.txt`, `spawndatatable.txt`, `spawninstancetable.txt`, `aidatatable.txt`, `itemdatatable.txt`, `itemdroptable.txt`, `groupdroprate.txt`, `droprankrate.txt`, `skilltemplate.ini`, `skillspec.txt`, `skillconst*.txt`, `levelupexp.ini` y `growupfactor.ini`. `world/node_data` aporta el mapa lógico. | El árbol Git del pin enumera estos datos y los describe como archivos del servidor original. El checkout parcial del proyecto no los materializa para el laboratorio. Su disponibilidad en upstream y la licencia del código se comprueban por separado de los permisos de las tablas. |
| Directorio local de tablas del cliente | Aspectos, nombres y correspondencias de NPC, objetos y skills. Aporta `charactertemplate.ini`, complementos de progresión y catálogo del cliente para el modo sin Webzen. | Se inventariaron los nombres en `ini/` de la instalación `665`. El importador requiere archivos legibles con la estructura esperada. El inventario no certifica su contenido, integridad de cada TID ni derechos. |
| `Client.DataDir` | `world/b*x.ma2` para alturas del cliente y otros recursos de escena. | Se observaron 558 archivos en el primer nivel de `world/`, entre ellos `b002024x.ma2`. Queda por medir cobertura de Anchorville y correspondencia con los segmentos del servidor. |
| `--webzen` y `--traductions` | Catálogo alternativo de quests de Webzen, sus textos, curva y complementos. `--traductions` exige `--webzen`. | Las entradas y sus permisos están pendientes. El mantenedor distingue esta ruta de las 14 quests del cliente Archonia citadas en el pin. Conviene dejarla fuera del primer ensayo. |
| `content/*.sql` | Capa posterior de datos de ArchCore para la raíz configurada. | Usar solo reglas y filas revisadas. El primer ensayo puede aprovisionarse con entradas pequeñas del proyecto y dejar la importación completa como prueba aparte. |

El CLI ofrece `db-init`, `import` y herramientas de preparación de tablas del cliente. Para una prueba completa, crear primero esquemas en una MariaDB nueva y configurar `ARCHCORE_ROOT` y `Client.DataDir` para la copia aislada. `import` exige tablas de servidor y de cliente. Empieza por la altura, combina catálogos y regiones, carga spawns, mapa, botín e IA y aplica la capa de contenido. `import_run` registra huellas y finalización por fuente. Una importación interrumpida puede dejar datos parciales. Conservar la huella, el resumen de filas y los TID descartados y repetir en otra base limpia antes de usar el resultado. La auditoría no ejecutó la importación con tablas originales. [Código de importación](../server/archcore/crates/archcore/src/tools/import.rs) · [inventario upstream en el pin](https://github.com/BlaMacfly/ArchCore/tree/ad280a6efc069526fc58445e5397d52a0e809500/data/server-ini) · [instalación upstream en el pin](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-Installation.md)

## Compatibilidad de protocolo con Archonia 665

El wiki del pin documenta la estructura de tramas y familias de módulos. Los identificadores y rutas comprobados estáticamente salen de `archcore-net/src/schema.rs` y de los emisores del servidor. La integración local valida los paquetes enumerados para el ensayo TCP. La columna gráfica indica lo que queda por observar en la instalación del parche `665`. [Protocolo en el pin](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-Network-protocol.md) · [esquemas Rust](../server/archcore/crates/archcore-net/src/schema.rs)

| Sistema mostrado | Paquetes implementados | Comprobación pendiente en `665` |
| --- | --- | --- |
| Aparición de NPC y monstruos | `OPT_VIEW` `0x42` op 1, mini de CID, TID, nombre y posición. Funciones del NPC en el bloque con eventos `0x3c`. `CHARACTER` `0x02` op 3 retira una entidad de la vista. | Correspondencia de TID con el modelo, altura de los pies, nombre, visibilidad al volver al sector y retirada. |
| Diálogo, servicios y tienda | `EVENT_NPC_DIALOG` `0x37` ops 0 y 1, `EVENT_NPC_TRADE` `0x32`, y módulos específicos para banco, teleport y maestro. | Ventana, texto de `npcdialog.txt`, lista, cantidades y precio. |
| Movimiento | `OPT_CHAR_MOVE` `0x40` emite origen, destino y flags de desplazamiento. | El movimiento del Knight ya se vio con velocidades de ensayo. Pendientes patrulla y persecución del mob, bloqueos y sincronización con dos clientes. |
| Ataque, daño y muerte | `OPT_CHAR_ACTION` `0x41` recibe atacante y objetivo y devuelve resultado y factores de daño. `CHARACTER` `0x02` op 1 actualiza estado, incluido muerto. `OPT_VIEW` publica el respawn. | Selección, alcance mostrado, animación, daño flotante, barra de HP y cadáver. |
| Experiencia, nivel y Gold | Factores y dinero en `CHARACTER` `0x02` op 1, subida de nivel en op 5. El texto de experiencia circula por `CHATTING` `0x0f`. | Barra de XP, nivel, aviso y monedero durante y después de reconectar. |
| Drops e inventario | `ITEM` `0x04` distingue suelo, inventario y equipo en sus actualizaciones. Recogida por op 11, resultado por op 12 y cambios de inventario en `ITEM` o en bloque de la vista inicial. | Modelo en suelo, icono, restricciones de recogida, cuadrícula y apariencia al equipar. |
| Habilidades y efectos | `SKILL` `0x05` para alta, actualización, uso y buffs. `EVENT_SKILL_MASTER` `0x3b` concede acceso al maestro. Acciones y factores sincronizan resultados. | Iconos, animación, efectos visuales de `effect/`, tiempos, consumo de MP y expiración. |
| Misiones | `EVENT_QUEST` `0x3e` y `QUEST` `0x13` para interacción, diario, progreso y recompensa. | Coincidencia de los TID de quest, grupo y objeto, interfaz, textos y recompensa. |

En la instalación se observaron `character/`, `effect/`, `object/`, `images/`, `texture/` y `world/`. `ini/` contiene `CharacterDataTable.txt`, `itemdatatable.txt`, `npc.ini`, `npcdialog.txt`, `npctradeitemlist.txt`, `SKILLTEMPLATE.ini`, `SKILL_CONST.txt`, `questtemplate.ini` y `questgroup.ini`. Se inspeccionaron nombres y presencia de archivos. El ejecutable inventariado tiene SHA-256 `e13603c37083aaa81e357a622f9cb99b32044f922d18441660c98d87290bb1a6`.

El mantenedor informa de NPC, diálogos, compras e inventario parcial en su cliente. La revisión y compilación de cliente de esos resultados requieren confirmación específica para aplicarlos a `665`. [README público de ArchCore](https://github.com/BlaMacfly/ArchCore)

## Evidencia de pruebas

| Prueba | Resultado y alcance |
| --- | --- |
| Build y unidad en la copia aislada del pin con parches | `cargo build` y `cargo test` en release Windows x64 con `--offline --locked`. Pasaron 382 tests de `archcore` y 11 de `archcore-net`. Una integración quedó marcada `ignored` en esa ejecución normal. |
| Casos representativos de unidad | `la_vue_contient_les_fonctions`, `resolution_par_cid_ou_par_evenement`, `evite_le_sol_bloque`, `promenade_dans_la_zone`, `chance_de_toucher`, `or_objets_de_groupe_et_propres`, `retrait_en_transaction`, `restrictions`, `points_de_competence`, `effets_sur_un_joueur` y `conditions_et_objectifs`. |
| Integración de TCP y MariaDB desechable | Pasó una ejecución explícita de la integración ignorada ampliada temporalmente. Login `12102`, World `12108` y MariaDB `3347`, en bucle local. Incluyó cierre ordenado, nuevo Blowfish, vinculación de cuenta, rechazo de variantes inválidas, clave de un solo uso, regreso y caducidad. |
| Extensión sintética de jugabilidad | Con un NPC y un mob creados para la prueba, el cliente Rust comprobó ambas vistas, permiso de diálogo, golpe al mob, muerte, retirada, respawn, subida de nivel, Gold en suelo y recogida. Afirmó en SQL `(level, exp, money) = (2, 5, 7)` para el personaje temporal. Ambas vistas volvieron a recibirse en la segunda entrada. |
| Sesiones gráficas previas | Login, creación y lista del Knight, entrada, escena, movimiento por clic, posición recuperada y dos regresos a selección con `665`. En la auditoría se usó inventario de archivos y evidencia previa. Pendientes un recorrido gráfico de juego con contenido y la recuperación de estado tras reiniciar World desde una instalación limpia. |

La compilación y el recorrido base se pueden repetir con [el script de regresión y sus dependencias](ARCHCORE_RETURN_INTEGRATION.md#reproducción-local). La extensión experimental quedó en `.local/archcore-return-integration-gameplay-audit/crates/archcore/src/tools/sim/return_regression.rs`. Añade a la fixture base un NPC TID `9801` con función de diálogo `21`, un mob TID `9802` a 20 unidades del personaje, `Type=196608`, `MAX_HP=1`, `Exp=15`, Gold fijo `7`, y umbrales de XP `10` y `100` para niveles 1 y 2. Son valores sintéticos para observar el protocolo. La MariaDB de la prueba se apagó al finalizar. El log de resultado queda en `.local/archcore-return-integration-gameplay-audit/return-fixture-gameplay-audit/regression.log`. Las cuentas, contraseñas, tablas de ensayo y logs quedaron fuera del historial Git.

Comandos ya disponibles para ampliar la cobertura incluyen `archcore sim shop`, `combat`, `equip`, `gold`, `skill`, `effects`, `quest`, `questobject` y `questgather`. Algunos presuponen cuentas GM, spawns o catálogos concretos. Revisar esos requisitos y ejecutarlos contra una instancia desechable. El pase de unidades no equivale a haber ejecutado esos escenarios. [Entradas y prerrequisitos del simulador](../server/archcore/crates/archcore/src/tools/sim.rs)

## Carencias, riesgos y dependencias

- **Catálogos y permisos.** El manifiesto de ArchCore declara el código `GPL-3.0-or-later`. El origen y los permisos de las tablas originales, el mapa y los recursos de Archonia requieren su propia comprobación. Guardar fuera de Git los archivos propietarios y anotar versión, origen y uso autorizado de cada entrada. Usar filas sintéticas propias con identificadores comprobados localmente mientras falten fuentes autorizadas. La fidelidad EP8 requiere datos de edición verificados. [Manifiesto del pin](../server/archcore/Cargo.toml) · [revisión de procedencia](ARCHCORE_RETURN_INTEGRATION.md#licencia-y-procedencia)
- **Consistencia de terreno y TID.** Cotejar catálogo de cliente, modelo del servidor, spawn, altura, bloqueos y región antes de diagnosticar un fallo como error de protocolo. Incluir un control con conteos de spawns por zona, posición en superficie y el aviso de World de entidades enviadas. Conservar el TID del personaje y sus datos en las pruebas que ejerciten regreso y reinicio.
- **Fidelidad y paridad con el cliente.** Las fórmulas y catálogos tienen aproximaciones y dependencias de la edición. Las tiendas y los intercambios requieren pruebas de saldo e inventario con rechazos. El combate necesita casos para represalia, muerte del jugador, resurrección, dos clientes y límites de daño. Para skills y quests se necesita una muestra representativa por tipo y una prueba de persistencia. Las operaciones de quest 12 y 13 carecen de tratamiento en el pin. El propio código señala que el cliente analizado no registra receptores para ellas, así que no hay evidencia de que bloqueen el primer ciclo. [Despachador y notas de quests](../server/archcore/crates/archcore/src/world/quests.rs)
- **Cobertura fuera del núcleo.** Los spawns propios de Archonia que el cliente no define y los modos exclusivos excluidos por el mantenedor, como rifts y pase de batalla, necesitan diseño o datos adicionales si se incorporan al alcance. Las correcciones de paquetes, mapeos o UI se justifican después de reproducir una divergencia concreta. Priorizar ese trabajo sobre sistemas existentes solo cuando un caso con datos correctos falle. [Alcance del pin](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-Episode.md)

## Ruta priorizada hacia un EP8 jugable

Estas fases desarrollan la prueba de jugabilidad de la [hoja de ruta general](ROADMAP.md). El primer escenario también sirve para reproducir desde un esquema limpio la entrada, movimiento, regreso a selección y posición posterior a un reinicio, pendientes de la fase de prueba de concepto.

| Prioridad | Reutilizar de ArchCore | Datos y configuración | Desarrollo y criterio de salida |
| --- | --- | --- | --- |
| 1. Mundo vivo | Registros de NPC y mobs, visibilidad, terreno y permisos de diálogo. | Un sector de Anchorville con un Knight de prueba, un NPC, un mob, TID comprobados y posiciones transitables. | Preparar el aprovisionamiento reproducible. Ambos aparecen en `665`, desaparecen al salir de vista, reaparecen al volver y el NPC abre su diálogo. Registrar un reinicio con recuperación del personaje. |
| 2. Combate básico | Acción básica, factores, IA, muerte y respawn. | Un perfil de IA, estadísticas, alcance y punto de resurrección adecuados, y dos cuentas de ensayo. | Validar golpe, represalia, muerte, resurrección y respawn. Corregir diferencias de movimiento, alcance o señales si la prueba las reproduce. |
| 3. Progresión y loot | XP, subida de nivel, monedero, tiradas y recogida. | Curva y crecimiento iniciales, un Gold fijo y un TID de objeto en una tabla controlada. | Comprobar una muerte, crédito de XP y Gold, recogida de un objeto y estado tras reconectar. Probar reserva e inventario lleno. |
| 4. Inventario, equipo y habilidades | Cuadrícula, equipamiento y factores, maestro, aprendizaje y efectos. | Un objeto equipable, una skill de ataque, un buff y sus recursos `665`. | Verificar restricciones, MP, cooldown, expiración y persistencia. Programar correcciones puntuales en factores, eventos o UI según el fallo observado. |
| 5. Tiendas, quests y ampliación | Comercio, diario, recompensas, banco y otros eventos. | Una tienda con compra y venta, una misión corta con catálogo coherente y sus textos. | Verificar saldo e inventario, progreso y entrega con reconexión. Extender catálogo y servicios. Los modos sin implementación se priorizan por separado. |

### Primer objetivo para la siguiente rama

Preparar un escenario descartable de Anchorville con un NPC y un monstruo que Archonia `665` pueda representar. Partir del pin con los parches ya integrados. Crear la base con `db-init`, cargar solo las entradas revisadas del sector y documentar TID, posición, terreno, alcance y origen. Preparar un Knight de prueba independiente. Exportar únicamente conteos, metadatos de protocolo y huellas de los insumos autorizados.

La prueba automatizada debe demostrar un `OPT_VIEW` para cada entidad y el permiso de diálogo. En una sesión gráfica comprobar ambos modelos, un clic de diálogo y que al salir del sector y volver aparecen una sola vez. Guardar el punto del personaje de prueba y repetir la entrada tras reiniciar World. Con ese caso verificado, reutilizar el mismo mob para la primera prueba de combate y la misma cuenta de prueba para experiencia y botín.

## Preparación para EP3

ArchCore puede aportar autenticación, presencia, sectores, persistencia, inventario, motor de spawns, ciclo de combate, economía y diario. La arquitectura permite comprobar una combinación EP8 pequeña antes de variar la edición. Conservar las pruebas base de entrada, visibilidad y persistencia para detectar regresiones cuando cambien las tablas o los mapeos.

| Área | Comparación necesaria al iniciar EP3 |
| --- | --- |
| Razas, clases y estadísticas | Confirmar el catálogo de clases del cliente de referencia, plantillas, TID, puntos de inicio, factores base, crecimiento y regeneración. Identificar clases añadidas después con fuentes contemporáneas antes de decidir su tratamiento. |
| Skills, buffs y combate | Comparar disponibilidad, requisitos, escalado, resistencias, críticos, velocidad, efectos y estados. Ver qué campos entiende el cliente objetivo y qué extensiones aparecieron en ediciones posteriores. |
| XP, equipo y economía | Investigar las curvas de nivel, recompensas y tasas, restricciones por clase y nivel, opciones de equipo, catálogo y precios. Registrar fuente y edición de cada tabla cuando exista evidencia. |
| Mundo e interfaz | Comparar mapas, coordenadas, modelos, animaciones, iconos, audio y textos. Archonia se puede probar con un perfil aislado de configuración, catálogos o recursos autorizados. Un cliente clásico requerirá volver a validar versión, handshake, esquemas y serialización. |

La referencia del proyecto sigue siendo *Spirits Awakening* de Codemasters. La cronología del mantenedor sirve para orientar la búsqueda. El anuncio de Webzen sobre el traspaso permite acotar la época, y las mediciones del laboratorio solo corresponden al pin EP8 con `665`. Para fijar valores de EP3 se necesitan fuentes independientes y permisos por componente. [Viabilidad técnica de EP3](EP3_SERVER_FEASIBILITY.md) · [cronología de ArchCore](https://github.com/BlaMacfly/ArchCore/blob/ad280a6efc069526fc58445e5397d52a0e809500/docs/wiki/EN-Episode.md) · [anuncio de Webzen](https://company.webzen.com/en/pr/pressview?page=81&seq=274)
