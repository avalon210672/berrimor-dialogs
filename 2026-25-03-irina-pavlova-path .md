# Платформа Ирины Павловой — Project Snapshot

## Обзор проекта

Веб-платформа для психолога/коуча **Ирины Павловой**. Личный кабинет клиента с психологическими тестами, аудио-войсчатами (Winamp-стиль плеер), курсами, практиками, блогом и админ-панелью. Интеграции с Telegram-ботом и Bitrix24 CMS.

**Опубликован**: https://irina-pavlova-path.lovable.app

---

## Технологический стек

| Слой | Технологии |
|------|-----------|
| Frontend | React 18, TypeScript, Vite 5 |
| Стили | Tailwind CSS 3 + shadcn/ui + glass-morphism дизайн-система |
| Состояние | TanStack React Query (кеш 5 мин), React Context (Auth, Theme) |
| Бэкенд | Supabase (Lovable Cloud): PostgreSQL, Auth, Storage, Edge Functions |
| Роутинг | react-router-dom v6 (lazy loading с retry на chunk failure) |
| Редактор | TipTap (блог-статьи) |
| Графики | Recharts (админ-статистика) |
| Шрифт | Inter (300–800) |

---

## Дизайн-система

### Тема: iOS mint / glass-morphism

- **Primary**: `hsl(200 80% 60%)` — sky blue
- **Secondary/CTA**: `hsl(168 60% 48%)` — mint green
- **Accent**: `hsl(168 50% 95%)` — light mint
- **Background (light)**: `hsl(210 40% 98%)` — frosted white
- **Background (dark)**: `hsl(222 20% 7%)` — deep navy
- **Border radius**: `1rem` (сильное скругление)
- **Glass-эффекты**: `backdrop-blur(20px)`, полупрозрачные карточки
- **Тени**: `shadow-glass`, `shadow-card`, `shadow-mint-glass` и др.

### Палитра mint (Tailwind)
`mint-50` → `mint-900` (полная шкала HSL 168°)

### Поддержка тёмной темы
Переключение через `ThemeContext` + class `dark` на `<html>`.

---

## База данных (16 таблиц)

### Основные таблицы

| Таблица | Назначение | Ключевые поля |
|---------|-----------|---------------|
| `profiles` | Профили пользователей | `id` (= auth.uid), `full_name`, `email`, `avatar_url` |
| `user_roles` | Роли (admin/user) | `user_id`, `role` (enum: admin, user) |
| `content` | Единый контент (тесты, курсы, практики, войсчаты) | `id`, `title`, `content_type` (enum), `content_data` (jsonb), `category` |
| `voicechats` | Аудио-войсчаты | `content_id` (→content), `audio_url`, `folder` (enum), `summary`, `duration` |
| `tests` | Вопросы тестов | `content_id` (→content), `questions` (jsonb), `scoring_logic` (jsonb) |
| `test_results` | Результаты тестов | `user_id`, `test_id`, `answers` (jsonb), `score`, `is_draft` |
| `user_content_access` | Доступ к контенту (ручное назначение) | `user_id`, `content_id`, `granted_by` |
| `course_progress` | Прогресс прохождения курсов | `user_id`, `content_id`, `progress` (0–100) |
| `content_views` | Просмотры контента | `user_id`, `content_id`, `view_duration_seconds` |
| `user_sessions` | Сессии пользователей (heartbeat) | `user_id`, `started_at`, `duration_seconds`, `page_views` |
| `events` | Календарь событий | `title`, `event_date`, `event_time`, `description` |

### Блог

| Таблица | Назначение |
|---------|-----------|
| `articles` | Статьи блога (title, content, html_content, SEO-поля, status, scheduled_at) |
| `categories` | Категории статей (name, bitrix_id, is_synced) |
| `reviews` | Отзывы (title, image_url, description, status) |
| `published_articles` | Лог публикаций в Bitrix24 (article_id, bitrix_id, response) |
| `published_reviews` | Лог публикаций отзывов в Bitrix24 |

### Настройки

| Таблица | Назначение |
|---------|-----------|
| `app_settings` | Настройки приложения (jsonb) |
| `site_settings` | Настройки сайта (key/value text) |
| `telegram_whitelist` | Белый список Telegram-пользователей |

---

## Аутентификация и авторизация

### Аутентификация
- Email + пароль (Supabase Auth)
- **Email-подтверждение обязательно** (auto-confirm отключён)
- Сброс пароля через email → `/reset-password`
- Профиль создаётся через триггер при регистрации

### Авторизация (RLS)
- Роли хранятся в `user_roles` (отдельная таблица, НЕ в profiles)
- SQL-функции: `is_admin(user_uuid)`, `has_role(_user_id, _role)`, `get_user_role(user_uuid)`
- **Войсчаты**: открыты всем авторизованным (`content_type = 'voicechat'`)
- **Тесты/курсы**: доступ через `user_content_access` (ручное назначение админом)
- **Админ**: полный доступ ко всем таблицам через `has_role(auth.uid(), 'admin')`

---

## Маршрутизация

```
/                          — Главная (Index) + авторизация
/reset-password            — Сброс пароля
/tests                     — Список тестов
/test/:contentId           — Прохождение теста
/voicechats                — Войсчаты (все папки)
/category/:folderId        — Войсчаты папки

/admin                     — Админ-дашборд (защита: AdminRoute)
/admin/users               — Управление пользователями
/admin/voicechats          — Управление войсчатами
/admin/tests               — Управление тестами
/admin/courses             — Управление курсами
/admin/intensive           — Интенсивы
/admin/practices           — Практики
/admin/test-results        — Результаты тестов
/admin/statistics          — Статистика
/admin/calendar            — Календарь событий
/admin/blog                — Блог-дашборд
/admin/blog/articles       — Статьи
/admin/blog/articles/:id   — Редактор статьи
/admin/blog/reviews        — Отзывы
/admin/blog/reviews/:id    — Редактор отзыва
/admin/blog/categories     — Категории
/admin/blog-settings       — Настройки блога
```

Все маршруты lazy-loaded с `lazyWithRetry` (перезагрузка при chunk failure).

---

## Edge Functions (17 шт.)

| Функция | Назначение |
|---------|-----------|
| `unpack-voicechat` | Загрузка войсчатов (ZIP или прямой файл → Storage + DB) |
| `generate-voicechat-summary` | Генерация AI-саммари для войсчата |
| `analyze-test-results` | AI-анализ результатов теста |
| `analyze-symptom-indicator` | AI-анализ симптом-индикатора |
| `delete-user` | Удаление пользователя (с каскадом) |
| `get-storage-usage` | Расчёт использования Storage |
| `generate-seo` | AI-генерация SEO-полей для статьи |
| `generate-image` | AI-генерация изображений |
| `publish-to-bitrix` | Публикация статьи в Bitrix24 |
| `publish-review-to-bitrix` | Публикация отзыва в Bitrix24 |
| `sync-categories` | Синхронизация категорий с Bitrix24 |
| `test-bitrix` | Тест подключения к Bitrix24 |
| `import-blog-data` | Импорт данных блога из JSON |
| `process-article-docx` | Обработка DOCX-файла статьи |
| `publish-scheduled-articles` | Автопубликация запланированных статей |
| `telegram-webhook` | Вебхук Telegram-бота |
| `verify-telegram-token` | Проверка Telegram-токена |

Все функции с `verify_jwt = false` (авторизация внутри функций).

---

## Ключевые фичи

### 1. Психологические тесты (5 типов)
- **Архетип и Тень** — Юнгианские архетипы (slider-вопросы)
- **Эмоциональное мастерство** — Оценка EQ
- **LSI (Life Style Index)** — Индекс жизненного стиля
- **SoulEase** — Диагностика состояния
- **Симптом-индикатор** — Психосоматика (multiple choice)

Каждый тест: Landing → Questions (slider/multiple-choice) → Results + AI-анализ + PDF-экспорт (jsPDF).

### 2. Winamp-стиль аудиоплеер
Ретро-стилизованный плеер для войсчатов с:
- Плейлист с навигацией
- Summary (краткое описание)
- Группировка по папкам: Архетипы, Границы, Детство, Осознанность, Отношения, Психосоматика
- Сортировка: от старых к новым (`created_at ASC`)

### 3. Блог/CMS
- TipTap WYSIWYG-редактор
- SEO-поля (meta, OG, Twitter)
- Статусы: draft/published/scheduled
- Автопубликация по расписанию
- Загрузка DOCX
- AI-генерация SEO
- AI-генерация изображений
- Публикация в Bitrix24 + Telegram

### 4. Админ-панель
- Дашборд с метриками
- CRUD пользователей (с удалением через Edge Function)
- Управление контентом (тесты, курсы, практики, войсчаты)
- Назначение доступа к контенту (per-user, per-content)
- Просмотр результатов тестов
- Статистика (графики роста пользователей, сессии)
- Календарь событий

### 5. Интеграции
- **Telegram-бот**: вебхук, белый список, публикация статей/отзывов
- **Bitrix24**: публикация статей и отзывов, синхронизация категорий

### 6. Трекинг
- Сессии пользователей (heartbeat 60с, visibilitychange, beforeunload)
- Просмотры контента (content_views)
- Прогресс курсов (course_progress)

---

## Storage (Supabase)

| Бакет | Назначение |
|-------|-----------|
| `voicechats` | Аудио-файлы войсчатов (mp3, wav, flac, ogg) |
| `avatars` | Аватары пользователей |

---

## Структура файлов

```
src/
├── components/
│   ├── admin/         — AdminLayout, AdminSidebar, AdminRoute, диалоги доступа
│   ├── auth/          — AuthPage, LoginForm, RegisterForm, ForgotPasswordForm
│   ├── blog/          — RichTextEditor (TipTap)
│   ├── calendar/      — EventCalendar
│   ├── cards/         — MaterialCard, WelcomeCard
│   ├── dashboard/     — ClientDashboard, AboutSection, ProgressStats
│   ├── layout/        — Header, Footer, TelegramButton
│   ├── materials/     — MaterialDetailDialog
│   ├── test/          — Landing/Questions/Results для каждого теста
│   ├── ui/            — shadcn/ui компоненты
│   └── voicechat/     — AudioPlayer, WinampPlayer, VoicechatUploadDialog
├── contexts/          — AuthContext, ThemeContext
├── hooks/             — useAuth, useProfile, useCourseProgress, useContentTracking и др.
├── lib/               — Скоринг тестов, профили, PDF-экспорт, voicechatFolders, storageUtils
├── pages/
│   ├── admin/         — Все админ-страницы
│   └── *.tsx          — Пользовательские страницы
└── integrations/supabase/ — client.ts, types.ts (auto-generated)

supabase/functions/     — 17 Edge Functions
```

---

## Паттерны и конвенции

1. **Lazy loading**: все маршруты кроме Index через `lazyWithRetry`
2. **React Query**: staleTime 5 мин, gcTime 10 мин, retry 1
3. **RLS everywhere**: доступ к данным через Supabase RLS-политики
4. **Роли в отдельной таблице**: `user_roles` (не в profiles!)
5. **Content-type система**: единая таблица `content` + специализированные таблицы (voicechats, tests)
6. **Доступ к контенту**: через `user_content_access` (кроме войсчатов — они публичны для авторизованных)
7. **Edge Functions**: `verify_jwt = false`, авторизация внутри
8. **Темы**: light/dark через CSS-переменные + Tailwind `dark:` prefix
9. **Семантические токены**: все цвета через `--primary`, `--secondary` и т.д.
10. **Язык интерфейса**: русский

---

*Snapshot создан: 2026-03-25*
