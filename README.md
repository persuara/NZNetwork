# NZNetwork

# Conventional Commits

- For each Merge Request, all commits must adhere to [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) spec.
- Whenever possible, use a module name as a scope (e.g. `fix(service): Fix ProfileResponse issue.`).
- Use a proper sentence as a description — start with an uppercase letter, end with a dot.

## Allowed commit types

- <font color="grey">`build`</font><sup>*</sup>: Changes that affect build system (e.g. Gradle update)
- `chore`: Changes other than source or test code (e.g. library version updates)
- <font color="grey">`ci`</font><sup>*</sup>: CI configuration
- <font color="grey">`docs`</font><sup>*</sup>: Documentation changes
- `feat`: A new feature
- `fix`: Bug fixes
- `i18n`: Internationalization and translations
- `perf`: Performance Improvements
- `refactor`: A change in the source code that neither fixes a bug nor adds a feature
- `revert`: Reverting a commit
- <font color="grey">`style`</font><sup>*</sup>: Code style changes, not affecting code meaning (formatting)
- <font color="grey">`test`</font><sup>*</sup>: Adding new tests or improving existing ones
- `theme`: Changes related to UI theming

## Conventional Branches

For each Branch, the name of branch must follow this pattern (`CommitType`/`JIRACODE`/`SUBJECT`)
For example (`feat/MOB-231/AddMetaObservable`)
