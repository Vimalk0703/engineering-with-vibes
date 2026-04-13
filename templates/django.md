# Architecture Specification: Django Application

## Project Identity
- **Type**: Django Web Application / REST API
- **Language**: Python 3.11+ with type hints
- **Primary Framework**: Django (and Django REST Framework)
- **Package Manager**: pip / poetry / uv

## Mandatory Rules

1. **Fat Models, Skinny Views** -- place business logic in models, model managers, or services, not in views.
2. **Explicit app boundaries** -- logic should be modularized into reusable Django apps (`apps/`). Avoid cross-app circular dependencies.
3. **Class-Based Views (CBVs) preferred** -- use CBVs for reusability, but functional views are acceptable for very simple one-off endpoints.
4. **Django REST Framework (DRF) for APIs** -- use DRF serializers instead of manual JSON serialization.
5. **Never commit secrets** -- use environment variables via `django-environ` for configurations like `SECRET_KEY` and database credentials.
6. **Always use Custom User Model** -- start every project with a custom user model `AUTH_USER_MODEL` even if it is identical to default.
7. **Migrations strictly versioned** -- never modify or squash migration files manually unless strictly required and tested.
8. **Use ORM explicitly** -- avoid N+1 queries by proactively using `select_related()` and `prefetch_related()`.
9. **No wildcard `*` imports** -- explicit imports only for clarity and preventing namespace pollution.
10. **Split settings by environment** -- maintain `base.py`, `local.py`, `production.py` or use environment variables to toggle configurations safely.

## Directory Structure

```text
myproject/
├── manage.py               # Django management script
├── config/                 # Main project configuration
│   ├── settings/           # Split settings modules
│   │   ├── __init__.py
│   │   ├── base.py         # Shared settings
│   │   ├── local.py        # Development settings
│   │   └── production.py   # Production settings
│   ├── urls.py             # Root URL configuration
│   ├── asgi.py
│   └── wsgi.py
├── apps/                   # Django applications folder
│   ├── users/              # Example app
│   │   ├── models.py       # Data models
│   │   ├── views.py        # Request handlers (CBVs/FBVs)
│   │   ├── urls.py         # App URL routing
│   │   ├── admin.py        # Django admin config
│   │   ├── services.py     # Complex business logic
│   │   ├── serializers.py  # DRF serializers (if API)
│   │   └── tests/          # App tests
│   └── [other_app]/
├── requirements/           # Dependencies
└── templates/              # Global HTML templates
```

## Naming Conventions
- **Apps**: plural nouns (e.g., `users`, `products`, `orders`)
- **Files**: snake_case (`models.py`, `views.py`)
- **Models**: PascalCase (singular) (`User`, `Product`)
- **Functions/variables**: snake_case
- **Constants**: UPPER_SNAKE_CASE
- **Templates**: `app_name/model_action.html` (e.g. `users/user_list.html`)

## Architecture Patterns
- **Services layer**: Extract complex business logic from views/models into a `services.py` file per app to keep views clean.
- **Model Managers**: Use custom `models.Manager` and `models.QuerySet` for complex, reusable ORM queries.
- **Signals with caution**: Use signals sparingly as they implicitly couple code. Prefer explicit function calls in services.
- **DRF Serializers**: Use `ModelSerializer` for API validation and output formatting. Validation logic belongs here, business logic belongs in services.

## Testing Strategy
- **Framework**: pytest with pytest-django
- **Coverage**: >80% for business logic and critical apps
- **Fixtures**: Use `factory_boy` instead of manual object creation or raw JSON fixtures for testing models.
- **Approach**: Test views (responses, status codes), serializers (validation routines), and models/services (core logic).

## Security Baseline
- CSRF protection enabled for all form submissions (default).
- Session and CSRF cookies set to `Secure` and `HttpOnly` in production.
- Use Django's built-in password hashers (Argon2 preferred).
- Django Admin secured, accessible only via secure connection, optionally limited by IP.
- Input validation offloaded strictly to Django Forms or DRF Serializers.

## Performance Budgets
- Use `select_related` for foreign keys and `prefetch_related` for many-to-many fields to eliminate N+1 latency.
- Database indexes defined on frequently filtered/ordered columns (`db_index=True`, `class Meta: indexes = [...]`).
- Cache expensive queries or rendered fragments using Redis via Django's cache framework.

## Quality Gate Levels
- Level 1 (always): Migrations up-to-date, tests pass, linter (flake8/ruff) clean.
- Level 2 (10+ models): Test coverage >80%, zero N+1 query warnings (verified via tests or debug-toolbar).
- Level 3 (multi-app): Strict boundary decoupling, no circular app dependencies.
- Level 4 (production): `python manage.py check --deploy` passes without critical warnings.

## Common Mistakes
1. **N+1 Queries** in templates or serializers causing massive database roundtrips.
2. **Missing Custom User Model** at project inception, making later user profile migrations exceptionally painful.
3. **Putting too much logic in Views/Serializers**, creating massive, untestable monolithic functions instead of using services.
4. **Committing `SECRET_KEY`** or database credentials into version control.
5. **Ignoring `select_for_update()`** in concurrent transaction scenarios, leading to race conditions.
6. **Hardcoding URLs** instead of using Django's `reverse()` or `{% url %}` tags.
7. **Modifying migrations manually** without understanding the database schema impact.
