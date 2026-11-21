# Flujo de trabajo con Git

El proyecto usa Git Flow simplificado. `main` contiene las versiones estables y `develop` integra el trabajo diario. Toda funcionalidad se desarrolla en una rama de trabajo. Los nombres de ramas y los mensajes de commit se escriben en inglés.

## Ramas y destinos

| Rama | Punto de partida | Destino y finalidad |
| --- | --- | --- |
| `main` | Commit inicial del repositorio | Versiones estables. Recibe PR de publicación y correcciones urgentes. |
| `develop` | Commit inicial de `main` | Integración del desarrollo. Recibe PR de funcionalidades, correcciones y sincronización con `main`. |
| `feature/<description>` | `develop` actualizado | PR hacia `develop` para una funcionalidad. Ejemplo `feature/local-session`. |
| `fix/<description>` | `develop` actualizado | PR hacia `develop` para una corrección. Ejemplo `fix/character-save`. |
| `hotfix/<description>` | `main` actualizado | PR hacia `main` para una corrección urgente. Tras integrarla, llevar el cambio a `develop` mediante otro PR. Ejemplo `hotfix/login-timeout`. |
| `release/<version>` | `develop` actualizado | PR hacia `main` cuando una versión necesite preparación. Después, incorporar a `develop` los cambios pendientes de la versión mediante otro PR. Ejemplo `release/0.1.0`. |

Sin rama de preparación, una versión probada puede pasar de `develop` a `main` mediante PR. Para devolver una versión o corrección urgente, abrir un PR de `main` a `develop` cuando `main` solo contenga los cambios que deben integrarse y el PR se pueda fusionar. Si hay conflictos, preparar la sincronización en una rama `fix/` desde `develop` y llevarla a revisión. Usar commits de merge en promociones y sincronizaciones para conservar el historial común.

## Trabajo diario

1. Consultar la rama activa y ejecutar `git status --short --branch`. Preservar los cambios existentes y revisar si afectan a la tarea.
2. Comprobar que la rama base esté actualizada. Cuando exista una rama remota, consultar o traer sus referencias con autorización. Si la base local está atrasada, actualizarla por avance rápido con autorización para el merge. Si las ramas divergen, revisar la diferencia antes de elegir la base. Crear una rama nueva desde la base indicada en la tabla.
3. Trabajar en cambios pequeños, cada uno con una sola finalidad. Ejecutar las comprobaciones aplicables y revisar el diff antes de preparar cada commit. Informar de cualquier comprobación pendiente y de su motivo.
4. Proponer un mensaje Conventional Commits en inglés con el formato `<type>(<optional scope>): <summary>`. Por ejemplo, `feat(world): add local character movement`, `fix(storage): persist character position` o `docs: update local setup instructions`. Si el PR se integra con squash, usar también ese formato en el mensaje del commit resultante. [Especificación de Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
5. Obtener autorización explícita antes de ejecutar un commit, un push, un merge o la creación de un PR. El push forzado y la reescritura de historial también requieren autorización explícita. Una autorización para una operación no se extiende a las demás.
6. Al entregar el trabajo, informar de la rama activa, los cambios realizados y las verificaciones.

## Arranque del repositorio

La rama activa es `main`, aún sin commits, y `develop` no existe localmente. Conviene crear una sola vez la base documental en `main` y crear `develop` en ese mismo commit.

Cuando se autorice el commit inicial, revisar primero el estado del repositorio y el índice. Añadir los archivos por nombre y comprobar que el índice final contiene únicamente los de esta propuesta.

```powershell
git status --short --branch
git diff --cached --name-only
git add -- .gitignore AGENTS.md docs/ROADMAP.md docs/ARCHITECTURE.md docs/GIT_WORKFLOW.md .github/PULL_REQUEST_TEMPLATE.md
git diff --cached --check
git diff --cached
```

Si la revisión y las comprobaciones se completan correctamente, este es el mensaje propuesto para el commit inicial y el comando posterior para crear la rama local `develop`.

```powershell
git commit -m "chore: bootstrap repository and Git workflow"
git switch -c develop
```

Antes de publicar, comprobar con autorización el estado real de `origin`. Si ya tiene historial, reconciliarlo antes de hacer push. Si el remoto está vacío, publicar primero `main` y después `develop` una vez autorizado el push. Mantener `main` como rama predeterminada propuesta y seleccionar `develop` como base de los PR ordinarios. Aplicar las protecciones cuando ambas ramas existan en GitHub. [Rama predeterminada en GitHub](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-branches-in-your-repository/changing-the-default-branch)

## Protecciones recomendadas en GitHub

| Ámbito | Configuración propuesta |
| --- | --- |
| `main` y `develop` | Exigir PR, exigir que se resuelvan las conversaciones de revisión y bloquear el borrado y los pushes forzados. Aplicar las reglas también a administradores cuando el plan lo permita. |
| Revisiones | Exigir una aprobación cuando haya una segunda persona habilitada para revisar. Si solo hay un mantenedor, exigir PR y comprobaciones sin un mínimo de aprobaciones, ya que el autor no puede aprobar su propio PR. |
| Comprobaciones requeridas | Activarlas cuando los trabajos de CI existan y hayan publicado un resultado. Dejar disponibles los commits de merge para las promociones y sincronizaciones entre ramas. |

Se puede usar un ruleset para las dos ramas o reglas de protección para cada una, según el plan y la visibilidad del repositorio. [Rulesets en GitHub](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets), [Reglas disponibles para rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets), [Aprobaciones requeridas](https://docs.github.com/en/pull-requests/how-tos/review-pull-requests/approving-a-pull-request-with-required-reviews)

## Comprobaciones de integración continua

- **Ahora.** Ejecutar un trabajo de documentación en cada PR hacia `develop` o `main` que compruebe Markdown, enlaces internos, espacios del diff y las exclusiones esperadas de `.gitignore` con rutas de prueba.
- **Al incorporar código.** Añadir trabajos de análisis estático, compilación y pruebas para la tecnología elegida. Usar datos de prueba propios para la integración automatizada y registrar las pruebas manuales de compatibilidad con el cliente autorizado.
- **Antes de exigir un trabajo.** Darle un nombre único y comprobar que se ejecuta en todos los PR a los que se aplica la regla, incluidos los que solo cambian documentación. Los filtros por ruta pueden dejar pendiente una comprobación obligatoria. [Protección de ramas en GitHub](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches), [Ejecuciones omitidas en GitHub Actions](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/skip-workflow-runs)
