# Промты для переноса блог-менеджера в Irina's Insight Platform

Каждый этап — готовый промт для вставки в чат целевого проекта.

---

## Этап 1: База данных и Storage

Скопируй и отправь в чат проекта **Irina's Insight Platform**:

---

```
Мне нужно добавить систему управления блогом в админ-панель. Создай следующие таблицы и настройки.

ВАЖНО: Новую систему аутентификации НЕ создавай. Используй существующую (useAuth из @/contexts/AuthContext, isAdmin).

## 1. SQL миграция — таблицы

Выполни следующую SQL миграцию:

-- Таблица категорий
CREATE TABLE IF NOT EXISTS public.categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  bitrix_id integer NULL,
  is_synced boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Таблица статей
CREATE TABLE IF NOT EXISTS public.articles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  content text NOT NULL DEFAULT '',
  html_content text NOT NULL DEFAULT '',
  image_url text NULL,
  category_id uuid NULL REFERENCES public.categories(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'draft',
  meta_title text NULL,
  meta_description text NULL,
  meta_keywords text NULL,
  canonical_url text NULL,
  og_title text NULL,
  og_description text NULL,
  og_image text NULL,
  twitter_title text NULL,
  twitter_description text NULL,
  twitter_image text NULL,
  author_id uuid NOT NULL,
  telegram_message_id text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Таблица публикаций статей
CREATE TABLE IF NOT EXISTS public.published_articles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id uuid NOT NULL REFERENCES public.articles(id) ON DELETE CASCADE,
  bitrix_id integer NULL,
  published_at timestamptz NOT NULL DEFAULT now(),
  action text NOT NULL DEFAULT 'create',
  response jsonb NULL
);

-- Таблица отзывов
CREATE TABLE IF NOT EXISTS public.reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL DEFAULT '',
  image_url text NULL,
  original_image_url text NULL,
  description text NULL,
  status text NOT NULL DEFAULT 'draft',
  author_id uuid NOT NULL,
  telegram_message_id text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Таблица публикаций отзывов
CREATE TABLE IF NOT EXISTS public.published_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL REFERENCES public.reviews(id) ON DELETE CASCADE,
  bitrix_id integer NULL,
  published_at timestamptz NOT NULL DEFAULT now(),
  action text NOT NULL DEFAULT 'create',
  response jsonb NULL
);

-- Белый список Telegram
CREATE TABLE IF NOT EXISTS public.telegram_whitelist (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  telegram_id text NOT NULL,
  name text NULL,
  created_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Таблица настроек приложения (если не существует)
CREATE TABLE IF NOT EXISTS public.app_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text NOT NULL UNIQUE,
  value jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Триггеры updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_categories_updated_at') THEN
    CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON public.categories FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_articles_updated_at') THEN
    CREATE TRIGGER update_articles_updated_at BEFORE UPDATE ON public.articles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_reviews_updated_at') THEN
    CREATE TRIGGER update_reviews_updated_at BEFORE UPDATE ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_app_settings_updated_at') THEN
    CREATE TRIGGER update_app_settings_updated_at BEFORE UPDATE ON public.app_settings FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
  END IF;
END $$;

## 2. Функции проверки ролей (если не существуют)

CREATE OR REPLACE FUNCTION public.is_admin(user_uuid uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = user_uuid AND role IN ('admin', 'superadmin'));
$$;

CREATE OR REPLACE FUNCTION public.is_superadmin(user_uuid uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = user_uuid AND role = 'superadmin');
$$;

CREATE OR REPLACE FUNCTION public.get_user_role(user_uuid uuid)
RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT role FROM public.user_roles WHERE user_id = user_uuid;
$$;

## 3. RLS политики

-- Включить RLS
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.published_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.published_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.telegram_whitelist ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- categories
CREATE POLICY "Admins can view categories" ON public.categories FOR SELECT TO public USING (is_admin(auth.uid()));
CREATE POLICY "Admins can create categories" ON public.categories FOR INSERT TO public WITH CHECK (is_admin(auth.uid()));
CREATE POLICY "Admins can manage categories" ON public.categories FOR ALL TO public USING (is_admin(auth.uid()));

-- articles
CREATE POLICY "Admins can view all articles" ON public.articles FOR SELECT TO public USING (is_admin(auth.uid()));
CREATE POLICY "Admins can create articles" ON public.articles FOR INSERT TO public WITH CHECK (is_admin(auth.uid()));
CREATE POLICY "Admins can update their articles" ON public.articles FOR UPDATE TO public USING (is_admin(auth.uid()));
CREATE POLICY "Admins can delete articles" ON public.articles FOR DELETE TO public USING (is_admin(auth.uid()));

-- published_articles
CREATE POLICY "Admins can view publications" ON public.published_articles FOR SELECT TO public USING (is_admin(auth.uid()));
CREATE POLICY "Admins can create publications" ON public.published_articles FOR INSERT TO public WITH CHECK (is_admin(auth.uid()));

-- reviews
CREATE POLICY "Admins can view all reviews" ON public.reviews FOR SELECT TO public USING (is_admin(auth.uid()));
CREATE POLICY "Admins can create reviews" ON public.reviews FOR INSERT TO public WITH CHECK (is_admin(auth.uid()));
CREATE POLICY "Admins can update their reviews" ON public.reviews FOR UPDATE TO public USING (is_admin(auth.uid()));
CREATE POLICY "Admins can delete reviews" ON public.reviews FOR DELETE TO public USING (is_admin(auth.uid()));

-- published_reviews
CREATE POLICY "Admins can view review publications" ON public.published_reviews FOR SELECT TO public USING (is_admin(auth.uid()));
CREATE POLICY "Admins can create review publications" ON public.published_reviews FOR INSERT TO public WITH CHECK (is_admin(auth.uid()));

-- telegram_whitelist
CREATE POLICY "Admins can view whitelist" ON public.telegram_whitelist FOR SELECT TO public USING (is_admin(auth.uid()));
CREATE POLICY "Admins can manage whitelist" ON public.telegram_whitelist FOR ALL TO public USING (is_admin(auth.uid()));

-- app_settings
CREATE POLICY "Admins can view settings" ON public.app_settings FOR SELECT TO authenticated USING (is_admin(auth.uid()));
CREATE POLICY "Admins can manage settings" ON public.app_settings FOR ALL TO authenticated USING (is_admin(auth.uid())) WITH CHECK (is_admin(auth.uid()));

## 4. Storage бакеты

Создай два публичных бакета:
- article-images
- review-images

## 5. Начальные данные app_settings

Вставь записи (INSERT ... ON CONFLICT DO NOTHING):
- registration_enabled → false
- telegram_bot_token → ""
- bitrix_api_url → ""
- bitrix_api_key → ""
- bitrix_infoblock_id → ""
- bitrix_reviews_api_url → ""
- bitrix_reviews_api_key → ""
- bitrix_reviews_infoblock_id → ""
- auto_publish_enabled → false
- auto_publish_reviews → false
```

---

## Этап 2: Edge Functions

Скопируй и отправь в чат проекта **Irina's Insight Platform**:

---

```
Создай 9 edge functions для блог-менеджера. ВСЕ функции должны иметь verify_jwt = false в config.toml.

### Функция 1: telegram-webhook

Файл: supabase/functions/telegram-webhook/index.ts

Полный код:
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import mammoth from "https://esm.sh/mammoth@1.6.0";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface TelegramMessage {
  message_id: number;
  from: {
    id: number;
    first_name: string;
    last_name?: string;
    username?: string;
  };
  chat: {
    id: number;
    type: string;
  };
  text?: string;
  caption?: string;
  document?: {
    file_id: string;
    file_unique_id: string;
    file_name?: string;
    mime_type?: string;
    file_size?: number;
  };
  photo?: Array<{
    file_id: string;
    file_unique_id: string;
    width: number;
    height: number;
    file_size?: number;
  }>;
}

interface TelegramUpdate {
  update_id: number;
  message?: TelegramMessage;
}

async function downloadTelegramFile(fileId: string, botToken: string): Promise<ArrayBuffer> {
  const fileInfoResponse = await fetch(
    `https://api.telegram.org/bot${botToken}/getFile?file_id=${fileId}`
  );
  const fileInfo = await fileInfoResponse.json();
  
  if (!fileInfo.ok || !fileInfo.result?.file_path) {
    throw new Error('Failed to get file path from Telegram');
  }
  
  const fileUrl = `https://api.telegram.org/file/bot${botToken}/${fileInfo.result.file_path}`;
  const fileResponse = await fetch(fileUrl);
  
  if (!fileResponse.ok) {
    throw new Error('Failed to download file from Telegram');
  }
  
  return await fileResponse.arrayBuffer();
}

async function parseDocxFile(arrayBuffer: ArrayBuffer): Promise<{ text: string; html: string }> {
  const options = {
    styleMap: [
      "p[style-name='Heading 1'] => h1:fresh",
      "p[style-name='Heading 2'] => h2:fresh",
      "p[style-name='Heading 3'] => h3:fresh",
      "p[style-name='Title'] => h1:fresh",
      "p[style-name='Subtitle'] => h2:fresh",
      "b => strong",
      "i => em",
      "u => u",
      "strike => s",
      "br => br"
    ],
    ignoreEmptyParagraphs: false
  };
  
  const textResult = await mammoth.extractRawText({ arrayBuffer });
  const htmlResult = await mammoth.convertToHtml({ arrayBuffer }, options);
  
  let html = htmlResult.value;
  
  html = html.replace(/<p><\/p>/g, '<br class="paragraph-break" />');
  
  html = html.replace(
    /^\s*<p>(?:<strong>)?#[а-яА-Яa-zA-Z0-9_]+(?:<\/strong>)?<\/p>\s*/i,
    ''
  );
  
  html = html.replace(
    /<p><strong>([^<]{5,120})<\/strong><\/p>/g,
    (match, text) => {
      const trimmedText = text.trim();
      if (trimmedText.startsWith('#')) return match;
      if (trimmedText.endsWith('.') && trimmedText.length > 80) return match;
      return `<h2>${trimmedText}</h2>`;
    }
  );
  
  let headingCount = 0;
  html = html.replace(/(<h[12][^>]*>)/gi, (match) => {
    headingCount++;
    return headingCount > 1 ? `<hr class="section-break" />${match}` : match;
  });
  
  return { text: textResult.value, html: html };
}

async function getBotToken(supabase: any): Promise<string> {
  const { data: settings } = await supabase
    .from('app_settings')
    .select('value')
    .eq('key', 'telegram_bot_token')
    .single();

  if (!settings?.value) {
    throw new Error('Telegram bot token not configured');
  }

  return typeof settings.value === 'string' 
    ? settings.value.replace(/"/g, '') 
    : String(settings.value);
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const update: TelegramUpdate = await req.json();
    console.log('Received Telegram update:', JSON.stringify(update, null, 2));

    if (!update.message) {
      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const message = update.message;
    const telegramId = message.from.id.toString();
    const username = message.from.username ? `@${message.from.username}` : null;
    const chatId = message.chat.id;
    const text = message.text || '';

    if (text === '/start' || text.startsWith('/start ')) {
      const welcomeMessage = `👋 <b>Добро пожаловать!</b>

📄 <b>Статьи:</b>
Отправьте файл в формате <b>.docx</b> (Microsoft Word)

<b>Структура документа:</b>
1️⃣ Первая строка: категория в виде хештега
   Например: <code>#психология</code>
2️⃣ Вторая строка: заголовок статьи
3️⃣ Далее: текст статьи с форматированием

📸 <b>Отзывы:</b>
Отправьте <b>изображение</b> (скриншот отзыва)

💡 Форматирование Word (жирный, курсив, списки) будет сохранено!`;

      await sendTelegramMessage(chatId, welcomeMessage, supabase);
      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: whitelistById } = await supabase
      .from('telegram_whitelist')
      .select('id, name')
      .eq('telegram_id', telegramId);

    const { data: whitelistByUsername } = username 
      ? await supabase
          .from('telegram_whitelist')
          .select('id, name')
          .eq('telegram_id', username)
      : { data: null };

    const whitelisted = whitelistById?.[0] || whitelistByUsername?.[0];

    if (!whitelisted) {
      console.log(`Telegram ID ${telegramId} / username ${username} not in whitelist`);
      await sendTelegramMessage(
        chatId, 
        `❌ У вас нет доступа к публикации статей.\n\nВаш Telegram ID: <code>${telegramId}</code>\nВаш username: ${username || 'не задан'}\n\nСообщите эти данные администратору.`,
        supabase
      );
      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (message.photo && message.photo.length > 0) {
      return await processReview(message, supabase, chatId);
    }

    if (!message.document) {
      await sendTelegramMessage(
        chatId,
        `📄 <b>Отправьте контент:</b>

• <b>.docx файл</b> — будет обработан как статья
• <b>Изображение</b> — будет сохранено как отзыв

<b>Для статьи (структура .docx):</b>
1️⃣ <code>#категория</code>
2️⃣ Заголовок
3️⃣ Текст статьи`,
        supabase
      );
      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const doc = message.document;
    const fileName = doc.file_name?.toLowerCase() || '';
    const isDocx = fileName.endsWith('.docx') || 
                   doc.mime_type === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

    if (!isDocx) {
      await sendTelegramMessage(
        chatId,
        '⚠️ Пожалуйста, отправьте файл в формате <b>.docx</b> (Microsoft Word)\n\nДругие форматы не поддерживаются.',
        supabase
      );
      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    let articleText = '';
    let articleHtml = '';

    try {
      const botToken = await getBotToken(supabase);
      console.log('Downloading file:', doc.file_id);
      
      const fileBuffer = await downloadTelegramFile(doc.file_id, botToken);
      console.log('File downloaded, size:', fileBuffer.byteLength);
      
      const parsed = await parseDocxFile(fileBuffer);
      articleText = parsed.text;
      articleHtml = parsed.html;
      console.log('File parsed, text length:', articleText.length);
    } catch (parseError) {
      console.error('Error processing docx:', parseError);
      await sendTelegramMessage(
        chatId,
        '❌ Ошибка при чтении файла. Убедитесь, что файл не повреждён и имеет формат .docx',
        supabase
      );
      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (articleText.length < 10) {
      await sendTelegramMessage(
        chatId,
        '⚠️ Файл пустой или содержит слишком мало текста. Минимум 10 символов.',
        supabase
      );
      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const lines = articleText.split('\n').filter((l: string) => l.trim());
    
    const hashtagMatch = lines[0]?.match(/^\s*#([а-яА-Яa-zA-Z0-9_]+)\s*$/);
    let categoryId: string | null = null;
    let titleLineIndex = 0;

    if (hashtagMatch) {
      const categoryName = hashtagMatch[1];
      titleLineIndex = 1;

      const { data: existingCategory } = await supabase
        .from('categories')
        .select('id')
        .ilike('name', categoryName)
        .single();

      if (existingCategory) {
        categoryId = existingCategory.id;
      } else {
        const { data: newCategory } = await supabase
          .from('categories')
          .insert({ name: categoryName, is_synced: false })
          .select('id')
          .single();
        
        if (newCategory) {
          categoryId = newCategory.id;
          console.log(`Created new category: ${categoryName}`);
        }
      }
    }

    const titleLine = lines[titleLineIndex] || '';
    const title = titleLine.replace(/^\s*#\S+\s*/, '').trim().slice(0, 100) || 'Без заголовка';
    const displayTitle = title.length > 50 ? title.slice(0, 50) + '...' : title;
    
    const contentStartIndex = titleLineIndex + 1;
    const contentLines = lines.slice(contentStartIndex);
    const content = contentLines.join('\n').trim() || articleText;

    let cleanedHtml = articleHtml;
    
    cleanedHtml = cleanedHtml.replace(
      /^\s*<p>(?:<strong>)?#[а-яА-Яa-zA-Z0-9_]+(?:<\/strong>)?<\/p>\s*/i,
      ''
    );
    
    const escapedTitle = title.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    cleanedHtml = cleanedHtml.replace(
      new RegExp(`^\\s*<p>(?:<strong>)?${escapedTitle}(?:<\\/strong>)?<\\/p>\\s*`, 'i'),
      ''
    );
    
    cleanedHtml = cleanedHtml.replace(
      new RegExp(`^\\s*<h2>${escapedTitle}<\\/h2>\\s*`, 'i'),
      ''
    );

    const htmlContent = cleanedHtml || formatToHtml(content);

    const { data: adminRole } = await supabase
      .from('user_roles')
      .select('user_id')
      .in('role', ['superadmin', 'admin'])
      .limit(1)
      .single();

    if (!adminRole) {
      await sendTelegramMessage(chatId, '❌ Ошибка: не найден администратор для привязки статьи.', supabase);
      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const telegramMsgId = message.message_id.toString();
    const { data: existingArticle } = await supabase
      .from('articles')
      .select('id, title')
      .eq('telegram_message_id', telegramMsgId)
      .maybeSingle();

    if (existingArticle) {
      console.log('Duplicate detected, article already exists:', existingArticle.id);
      const shortTitle = existingArticle.title.length > 30 
        ? existingArticle.title.slice(0, 30) + '...' 
        : existingArticle.title;
      await sendTelegramMessage(
        chatId,
        `ℹ️ Статья "${shortTitle}" уже была создана ранее.`,
        supabase
      );
      return new Response(JSON.stringify({ ok: true, duplicate: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: article, error: articleError } = await supabase
      .from('articles')
      .insert({
        title,
        content,
        html_content: htmlContent,
        category_id: categoryId,
        status: 'draft',
        author_id: adminRole.user_id,
        telegram_message_id: message.message_id.toString(),
      })
      .select('id')
      .single();

    if (articleError) {
      console.error('Error creating article:', articleError);
      await sendTelegramMessage(chatId, `❌ Ошибка создания статьи: ${articleError.message}`, supabase);
      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Generate SEO
    try {
      const seoResponse = await supabase.functions.invoke('generate-seo', {
        body: { title, content },
      });

      if (seoResponse.data && !seoResponse.error) {
        await supabase
          .from('articles')
          .update({
            meta_title: seoResponse.data.meta_title,
            meta_description: seoResponse.data.meta_description,
            meta_keywords: seoResponse.data.meta_keywords,
            og_title: seoResponse.data.og_title,
            og_description: seoResponse.data.og_description,
            twitter_title: seoResponse.data.twitter_title,
            twitter_description: seoResponse.data.twitter_description,
          })
          .eq('id', article.id);
      }
    } catch (seoError) {
      console.error('Error generating SEO:', seoError);
    }

    // Generate Image
    let imageGenerated = false;
    let imageError = '';
    try {
      console.log('Generating image for article:', article.id);
      const imageResponse = await supabase.functions.invoke('generate-image', {
        body: { title, content, articleId: article.id },
      });

      if (imageResponse.data?.imageUrl && !imageResponse.error) {
        await supabase
          .from('articles')
          .update({
            image_url: imageResponse.data.imageUrl,
            og_image: imageResponse.data.imageUrl,
            twitter_image: imageResponse.data.imageUrl,
          })
          .eq('id', article.id);
        imageGenerated = true;
        console.log('Image saved to article:', imageResponse.data.imageUrl);
      } else {
        imageError = imageResponse.data?.error || imageResponse.error?.message || 'Генерация не вернула изображение';
        console.warn('Image generation returned error:', imageError);
      }
    } catch (imgErr) {
      imageError = imgErr instanceof Error ? imgErr.message : 'Неизвестная ошибка';
      console.error('Error generating image:', imgErr);
    }

    // Check auto-publish
    const { data: autoPublishSetting } = await supabase
      .from('app_settings')
      .select('value')
      .eq('key', 'auto_publish_enabled')
      .single();

    const autoPublishEnabled = autoPublishSetting?.value === true || 
                               autoPublishSetting?.value === 'true';

    let published = false;
    let publishError = '';

    if (autoPublishEnabled) {
      try {
        console.log('Auto-publishing article:', article.id);
        const publishResponse = await supabase.functions.invoke('publish-to-bitrix', {
          body: { articleId: article.id }
        });

        if (publishResponse.data?.success && !publishResponse.error) {
          published = true;
          console.log('Article auto-published successfully');
        } else {
          publishError = publishResponse.error?.message || publishResponse.data?.error || 'Unknown error';
          console.error('Auto-publish failed:', publishError);
        }
      } catch (pubError) {
        publishError = pubError instanceof Error ? pubError.message : 'Unknown error';
        console.error('Auto-publish error:', pubError);
      }
    }

    const categoryInfo = categoryId ? ' в категории' : '';
    const shortPublishError = publishError.length > 150 ? publishError.slice(0, 150) + '...' : publishError;
    const shortImageError = imageError.length > 100 ? imageError.slice(0, 100) + '...' : imageError;
    
    let imageStatus = '';
    if (imageGenerated) {
      imageStatus = '✅ сгенерировано';
    } else if (imageError) {
      imageStatus = `⚠️ ошибка: ${shortImageError}`;
    } else {
      imageStatus = '❌ не сгенерировано';
    }
    
    let statusMessage = '';
    
    if (published) {
      statusMessage = `✅ Статья "${displayTitle}" создана${categoryInfo} и опубликована на сайте!\n\n🖼 Изображение: ${imageStatus}\n🌐 Статус: опубликована`;
    } else if (autoPublishEnabled && publishError) {
      statusMessage = `⚠️ Статья "${displayTitle}" создана${categoryInfo}, но публикация не удалась.\n\n🖼 Изображение: ${imageStatus}\n❌ Ошибка публикации: ${shortPublishError}\n\n📝 Откройте панель управления для ручной публикации.`;
    } else {
      statusMessage = `✅ Статья "${displayTitle}" создана${categoryInfo}!\n\n📄 Файл: ${doc.file_name}\n🖼 Изображение: ${imageStatus}\n📝 Статус: черновик\n🔗 Откройте панель управления для редактирования и публикации.`;
    }

    await sendTelegramMessage(chatId, statusMessage, supabase);

    return new Response(JSON.stringify({ ok: true, articleId: article.id, published }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error('Error processing Telegram webhook:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return new Response(JSON.stringify({ ok: false, error: errorMessage }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

async function sendTelegramMessage(chatId: number, text: string, supabase: any) {
  try {
    const { data: settings } = await supabase
      .from('app_settings')
      .select('value')
      .eq('key', 'telegram_bot_token')
      .single();

    if (!settings?.value) {
      console.error('Telegram bot token not configured');
      return;
    }

    const token = typeof settings.value === 'string' 
      ? settings.value.replace(/"/g, '') 
      : String(settings.value);

    const MAX_LENGTH = 4096;
    let messageText = text;
    
    if (text.length > MAX_LENGTH) {
      messageText = text.slice(0, MAX_LENGTH - 25) + '\n\n... (обрезано)';
    }

    const response = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: chatId,
        text: messageText,
        parse_mode: 'HTML',
      }),
    });

    const result = await response.json();
    if (!result.ok) {
      console.error('Telegram API error:', result);
    }
  } catch (error) {
    console.error('Error sending Telegram message:', error);
  }
}

function formatToHtml(text: string): string {
  return text
    .split('\n\n')
    .map((paragraph: string) => {
      if (!paragraph.trim()) return '';
      
      if (paragraph.match(/^[-•]\s/m)) {
        const items = paragraph
          .split('\n')
          .filter((line: string) => line.match(/^[-•]\s/))
          .map((line: string) => `<li>${line.replace(/^[-•]\s/, '')}</li>`)
          .join('');
        return `<ul>${items}</ul>`;
      }
      
      if (paragraph.match(/^\d+\.\s/m)) {
        const items = paragraph
          .split('\n')
          .filter((line: string) => line.match(/^\d+\.\s/))
          .map((line: string) => `<li>${line.replace(/^\d+\.\s/, '')}</li>`)
          .join('');
        return `<ol>${items}</ol>`;
      }
      
      return `<p>${paragraph.replace(/\n/g, '<br>')}</p>`;
    })
    .filter(Boolean)
    .join('\n');
}

async function cropImageTo16x9(imageBuffer: ArrayBuffer): Promise<Uint8Array> {
  const { Image } = await import("https://deno.land/x/imagescript@1.3.0/mod.ts");
  
  const bytes = new Uint8Array(imageBuffer);
  const image = await Image.decode(bytes);
  
  console.log(`Original image dimensions: ${image.width}x${image.height}`);
  
  const targetRatio = 16 / 9;
  const currentRatio = image.width / image.height;
  
  let cropWidth = image.width;
  let cropHeight = image.height;
  
  if (currentRatio > targetRatio) {
    cropWidth = Math.round(image.height * targetRatio);
  } else {
    cropHeight = Math.round(image.width / targetRatio);
  }
  
  const cropX = Math.round((image.width - cropWidth) / 2);
  const cropY = Math.round((image.height - cropHeight) / 2);
  
  console.log(`Cropping to 16:9: ${cropWidth}x${cropHeight} from position (${cropX}, ${cropY})`);
  
  image.crop(cropX, cropY, cropWidth, cropHeight);
  
  if (image.width > 640) {
    const scale = 640 / image.width;
    const newHeight = Math.round(image.height * scale);
    image.resize(640, newHeight);
    console.log(`Resized preview to: 640x${newHeight}`);
  }
  
  return await image.encodeJPEG(85);
}

async function processReview(message: TelegramMessage, supabase: any, chatId: number) {
  try {
    const botToken = await getBotToken(supabase);
    
    const photo = message.photo![message.photo!.length - 1];
    console.log('Processing review image:', photo.file_id);
    
    const imageBuffer = await downloadTelegramFile(photo.file_id, botToken);
    console.log('Image downloaded, size:', imageBuffer.byteLength);
    
    const baseFileName = `review_${Date.now()}_${Math.random().toString(36).slice(2)}`;
    
    const originalFileName = `${baseFileName}_original.jpg`;
    const { error: originalUploadError } = await supabase.storage
      .from('review-images')
      .upload(originalFileName, imageBuffer, {
        contentType: 'image/jpeg',
        upsert: false,
      });
    
    if (originalUploadError) {
      console.error('Original upload error:', originalUploadError);
      await sendTelegramMessage(chatId, '❌ Ошибка загрузки изображения: ' + originalUploadError.message, supabase);
      return new Response(JSON.stringify({ ok: true }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }
    
    const { data: originalUrlData } = supabase.storage
      .from('review-images')
      .getPublicUrl(originalFileName);
    const originalImageUrl = originalUrlData.publicUrl;
    console.log('Original image uploaded:', originalImageUrl);
    
    let previewImageUrl = originalImageUrl;
    
    try {
      const previewBytes = await cropImageTo16x9(imageBuffer);
      const previewFileName = `${baseFileName}_preview.jpg`;
      
      const { error: previewUploadError } = await supabase.storage
        .from('review-images')
        .upload(previewFileName, previewBytes, {
          contentType: 'image/jpeg',
          upsert: false,
        });
      
      if (previewUploadError) {
        console.warn('Preview upload error, using original:', previewUploadError.message);
      } else {
        const { data: previewUrlData } = supabase.storage
          .from('review-images')
          .getPublicUrl(previewFileName);
        previewImageUrl = previewUrlData.publicUrl;
        console.log('Preview image uploaded:', previewImageUrl);
      }
    } catch (cropError) {
      console.warn('Error creating preview, using original:', cropError);
    }
    
    const { data: adminRole } = await supabase
      .from('user_roles')
      .select('user_id')
      .in('role', ['superadmin', 'admin'])
      .limit(1)
      .single();
    
    if (!adminRole) {
      await sendTelegramMessage(chatId, '❌ Ошибка: не найден администратор.', supabase);
      return new Response(JSON.stringify({ ok: true }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }
    
    const title = message.caption || `Отзыв от ${new Date().toLocaleDateString('ru-RU')}`;
    const displayTitle = title.length > 50 ? title.slice(0, 50) + '...' : title;
    
    const { data: review, error: reviewError } = await supabase
      .from('reviews')
      .insert({
        title: title.slice(0, 200),
        image_url: previewImageUrl,
        original_image_url: originalImageUrl,
        description: message.caption || null,
        status: 'draft',
        author_id: adminRole.user_id,
        telegram_message_id: message.message_id.toString(),
      })
      .select('id')
      .single();
    
    if (reviewError) {
      console.error('Error creating review:', reviewError);
      await sendTelegramMessage(chatId, `❌ Ошибка создания отзыва: ${reviewError.message}`, supabase);
      return new Response(JSON.stringify({ ok: true }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }
    
    const { data: autoPublishSetting } = await supabase
      .from('app_settings')
      .select('value')
      .eq('key', 'auto_publish_reviews')
      .single();
    
    const autoPublishEnabled = autoPublishSetting?.value === true || 
                               autoPublishSetting?.value === 'true';
    
    let published = false;
    let publishError = '';
    
    if (autoPublishEnabled) {
      try {
        console.log('Auto-publishing review:', review.id);
        const publishResponse = await supabase.functions.invoke('publish-review-to-bitrix', {
          body: { reviewId: review.id }
        });
        
        if (publishResponse.data?.success && !publishResponse.error) {
          published = true;
          console.log('Review auto-published successfully');
        } else {
          publishError = publishResponse.error?.message || publishResponse.data?.error || 'Unknown error';
          console.error('Auto-publish failed:', publishError);
        }
      } catch (pubError) {
        publishError = pubError instanceof Error ? pubError.message : 'Unknown error';
        console.error('Auto-publish error:', pubError);
      }
    }
    
    let statusMessage = '';
    if (published) {
      statusMessage = `✅ Отзыв "${displayTitle}" сохранён и опубликован!`;
    } else if (autoPublishEnabled && publishError) {
      const shortError = publishError.length > 100 ? publishError.slice(0, 100) + '...' : publishError;
      statusMessage = `⚠️ Отзыв "${displayTitle}" сохранён, но публикация не удалась.\n\n❌ ${shortError}`;
    } else {
      statusMessage = `✅ Отзыв "${displayTitle}" сохранён!\n\n📝 Статус: черновик`;
    }
    
    await sendTelegramMessage(chatId, statusMessage, supabase);
    
    return new Response(JSON.stringify({ ok: true, reviewId: review.id, published }), {
      headers: { 'Content-Type': 'application/json' },
    });
    
  } catch (error) {
    console.error('Error processing review:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    await sendTelegramMessage(chatId, `❌ Ошибка обработки отзыва: ${errorMessage}`, supabase);
    return new Response(JSON.stringify({ ok: false, error: errorMessage }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
}
```

### Функция 2: generate-seo

Файл: supabase/functions/generate-seo/index.ts

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { title, content } = await req.json();

    const LOVABLE_API_KEY = Deno.env.get('LOVABLE_API_KEY');
    if (!LOVABLE_API_KEY) {
      throw new Error('LOVABLE_API_KEY not configured');
    }

    const prompt = `Сгенерируй SEO-теги для статьи на русском языке.

Заголовок: ${title}
Контент: ${content.slice(0, 1000)}

Верни JSON с полями:
- meta_title (до 60 символов)
- meta_description (до 160 символов)  
- meta_keywords (5-7 ключевых слов через запятую)
- og_title
- og_description
- twitter_title
- twitter_description

Только JSON, без markdown.`;

    const response = await fetch('https://ai.gateway.lovable.dev/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${LOVABLE_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'google/gemini-2.5-flash',
        messages: [{ role: 'user', content: prompt }],
      }),
    });

    const data = await response.json();
    const text = data.choices?.[0]?.message?.content || '{}';
    
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    const seoData = jsonMatch ? JSON.parse(jsonMatch[0]) : {};

    console.log('Generated SEO:', seoData);

    return new Response(JSON.stringify(seoData), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('Error generating SEO:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
```

### Функция 3: generate-image

Файл: supabase/functions/generate-image/index.ts

Это большая функция (582 строки). Она:
1. Анализирует контент статьи через AI (google/gemini-2.5-flash)
2. Генерирует фотореалистичное изображение (google/gemini-3-pro-image-preview или google/gemini-2.5-flash-image-preview)
3. Добавляет водяной знак "Pavlova Psy SPB" через AI-редактирование
4. Программно сжимает до 650KB через imagescript
5. Загружает в storage bucket article-images

Создай файл с этим полным кодом:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Image } from "https://deno.land/x/imagescript@1.3.0/mod.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const AI_MODELS = [
  "google/gemini-3-pro-image-preview",
  "google/gemini-2.5-flash-image-preview",
];

const MAX_BINARY_SIZE_KB = 650;
const TARGET_WIDTH = 640;
const TARGET_HEIGHT = 360;

const NO_TEXT_RULES = `
ABSOLUTE PROHIBITION - NO TEXT WHATSOEVER:
- NEVER include ANY text, letters, words, numbers, symbols, or typography
- NEVER include watermarks, logos, labels, captions, or titles  
- NEVER include signs, banners, buttons, or UI elements with text
- NEVER include handwriting, graffiti, or any written elements
- The image must be 100% VISUAL-ONLY with ZERO textual elements
- Any text in the image = REJECTED IMAGE`;

interface ImageAnalysis {
  mainTheme: string;
  emotionalTone: string;
  targetAudience: string;
  keyMetaphors: string[];
  visualElements: string[];
  mood: string;
  setting: string;
  suggestedScene: string;
}

function getImageSizeKB(base64Image: string): number {
  const base64Data = base64Image.replace(/^data:image\/\w+;base64,/, '');
  return Math.round(base64Data.length * 0.75 / 1024);
}

async function analyzeArticleContent(apiKey: string, title: string, content: string): Promise<ImageAnalysis | null> {
  console.log('Starting deep content analysis for:', title);
  
  const analysisPrompt = `Проанализируй статью по психологии и дай рекомендации для создания уникальной иллюстрации.

ЗАГОЛОВОК: ${title}

СОДЕРЖАНИЕ: ${content}

Твоя задача — понять ГЛУБИННЫЙ СМЫСЛ статьи и предложить визуальный образ, который:
1. Отражает конкретную тему (не общую "психологию")
2. Использует метафоры и символы из самого текста
3. Вызывает правильные эмоции у читателя
4. Запоминается и выделяется среди типичных стоковых изображений

ВАЖНО: Избегай банальных образов вроде "человек с чашкой чая", "терапевт в кресле", "руки, держащие сердце".

Ответь СТРОГО в JSON формате (без markdown, только чистый JSON):
{
  "mainTheme": "Основная тема статьи одним предложением",
  "emotionalTone": "Главная эмоция",
  "targetAudience": "Для кого написано",
  "keyMetaphors": ["метафора 1", "метафора 2"],
  "visualElements": ["элемент 1", "элемент 2", "элемент 3"],
  "mood": "Какое настроение должно вызвать изображение",
  "setting": "Обстановка: природа/интерьер/абстракция/город",
  "suggestedScene": "Подробное описание уникальной сцены для иллюстрации (2-3 предложения)"
}`;

  try {
    const response = await fetch("https://ai.gateway.lovable.dev/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "google/gemini-2.5-flash",
        messages: [{ role: "user", content: analysisPrompt }],
      }),
    });

    if (!response.ok) return null;

    const data = await response.json();
    const responseText = data.choices?.[0]?.message?.content;
    if (!responseText) return null;

    let jsonStr = responseText.trim();
    if (jsonStr.startsWith('```json')) jsonStr = jsonStr.slice(7);
    if (jsonStr.startsWith('```')) jsonStr = jsonStr.slice(3);
    if (jsonStr.endsWith('```')) jsonStr = jsonStr.slice(0, -3);
    jsonStr = jsonStr.trim();

    return JSON.parse(jsonStr);
  } catch (error) {
    console.error('Error during content analysis:', error);
    return null;
  }
}

function buildImagePromptFromAnalysis(analysis: ImageAnalysis): string {
  const metaphorsStr = analysis.keyMetaphors?.join(', ') || '';
  const visualElementsStr = analysis.visualElements?.join(', ') || '';
  
  return `Create a PHOTOREALISTIC, emotionally evocative image for a psychology article.

SCENE TO VISUALIZE:
${analysis.suggestedScene}

EMOTIONAL TONE: ${analysis.emotionalTone}
MOOD TO CONVEY: ${analysis.mood}
SETTING: ${analysis.setting}

KEY VISUAL ELEMENTS TO INCLUDE:
${visualElementsStr}

METAPHORICAL INSPIRATION:
${metaphorsStr}

STYLE REQUIREMENTS - CRITICAL:
- PHOTOREALISTIC photography style
- Warm, soft natural lighting (golden hour or soft diffused light)
- Shallow depth of field for cinematic look
- Muted, harmonious color palette
- Clean composition with clear focal point
- Artistic, editorial photography aesthetic
- NO CLICHÉS

${NO_TEXT_RULES}

TECHNICAL FORMAT:
- Horizontal aspect ratio 16:9
- Resolution: 1024x576 pixels or higher
- Output as high-quality JPEG
`;
}

function getFallbackPrompt(title: string, contentPreview: string, attempt: number): string {
  if (attempt === 0) {
    return `
Create a PHOTOREALISTIC image for a psychology and wellness blog article.

ARTICLE TITLE: "${title}"
ARTICLE CONTENT SUMMARY: ${contentPreview}

STYLE REQUIREMENTS:
- PHOTOREALISTIC photography style
- Warm, soft natural lighting
- Shallow depth of field
- Muted, warm color palette
- Clean, uncluttered composition

${NO_TEXT_RULES}

TECHNICAL FORMAT:
- Horizontal aspect ratio 16:9
- Resolution: 1024x576 pixels or higher
- Output as high-quality JPEG
`;
  } else {
    return `
Generate a calm, photorealistic lifestyle photograph for: "${title}"
Style: Professional photography, warm natural lighting, real people, soft focus background.
Mood: Peaceful, therapeutic, authentic.
Format: 16:9 horizontal, JPEG.
${NO_TEXT_RULES}
`;
  }
}

async function tryGenerateImage(apiKey: string, model: string, prompt: string): Promise<{ success: boolean; image?: string; error?: string }> {
  try {
    const response = await fetch("https://ai.gateway.lovable.dev/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        messages: [{ role: "user", content: prompt }],
        modalities: ["image", "text"]
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`AI Gateway error (${model}):`, response.status, errorText);
      if (response.status === 429) return { success: false, error: "rate_limit" };
      if (response.status === 402) return { success: false, error: "payment_required" };
      return { success: false, error: `HTTP ${response.status}` };
    }

    const data = await response.json();
    const image = data.choices?.[0]?.message?.images?.[0]?.image_url?.url;
    
    if (!image) return { success: false, error: "no_image_in_response" };
    if (!image.startsWith('data:image/')) return { success: false, error: "invalid_image_format" };

    return { success: true, image };
  } catch (error) {
    return { success: false, error: error instanceof Error ? error.message : "unknown" };
  }
}

async function compressImage(base64Image: string, maxSizeKB: number, targetWidth: number, targetHeight: number): Promise<Uint8Array> {
  const base64Data = base64Image.replace(/^data:image\/\w+;base64,/, '');
  const bytes = Uint8Array.from(atob(base64Data), c => c.charCodeAt(0));
  
  let image = await Image.decode(bytes);
  
  const targetAspect = targetWidth / targetHeight;
  const sourceAspect = image.width / image.height;
  
  let scaledWidth: number;
  let scaledHeight: number;
  
  if (sourceAspect > targetAspect) {
    scaledHeight = targetHeight;
    scaledWidth = Math.round(image.width * (targetHeight / image.height));
  } else {
    scaledWidth = targetWidth;
    scaledHeight = Math.round(image.height * (targetWidth / image.width));
  }
  
  image.resize(scaledWidth, scaledHeight);
  
  const cropX = Math.round((scaledWidth - targetWidth) / 2);
  const cropY = Math.round((scaledHeight - targetHeight) / 2);
  
  image = image.crop(cropX, cropY, targetWidth, targetHeight);
  
  const maxBytes = maxSizeKB * 1024;
  let quality = 85;
  let result: Uint8Array;
  
  do {
    result = await image.encodeJPEG(quality);
    if (result.length <= maxBytes) break;
    quality -= 10;
  } while (quality >= 20);
  
  if (result.length > maxBytes && quality < 20) {
    result = await image.encodeJPEG(10);
  }
  
  if (result.length > maxBytes) {
    const smallerWidth = Math.round(targetWidth * 0.7);
    const smallerHeight = Math.round(targetHeight * 0.7);
    image.resize(smallerWidth, smallerHeight);
    result = await image.encodeJPEG(50);
  }
  
  return result;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { title, content, articleId } = await req.json();
    const LOVABLE_API_KEY = Deno.env.get("LOVABLE_API_KEY");
    
    if (!LOVABLE_API_KEY) throw new Error("LOVABLE_API_KEY not configured");
    if (!title) throw new Error("Title is required");

    const contentForAnalysis = content?.slice(0, 3000) || '';
    const contentPreview = content?.slice(0, 400) || '';
    
    console.log('Step 1: Performing deep content analysis...');
    
    let imagePrompt: string;
    let usedAnalysis = false;
    
    const analysis = await analyzeArticleContent(LOVABLE_API_KEY, title, contentForAnalysis);
    
    if (analysis && analysis.suggestedScene) {
      imagePrompt = buildImagePromptFromAnalysis(analysis);
      usedAnalysis = true;
    } else {
      imagePrompt = getFallbackPrompt(title, contentPreview, 0);
    }
    
    console.log('Step 2: Generating base image for:', title);
    
    let baseImage: string | null = null;
    let lastError = '';
    
    for (let attempt = 0; attempt < 3; attempt++) {
      const modelIndex = Math.min(attempt, AI_MODELS.length - 1);
      const model = AI_MODELS[modelIndex];
      
      const promptToUse = (attempt > 0 && usedAnalysis) 
        ? getFallbackPrompt(title, contentPreview, attempt)
        : imagePrompt;
      
      const result = await tryGenerateImage(LOVABLE_API_KEY, model, promptToUse);
      
      if (result.success && result.image) {
        baseImage = result.image;
        break;
      }
      
      lastError = result.error || 'unknown';
      
      if (result.error === 'rate_limit') {
        return new Response(JSON.stringify({ error: "Rate limit exceeded." }), {
          status: 429,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }
      if (result.error === 'payment_required') {
        return new Response(JSON.stringify({ error: "Payment required." }), {
          status: 402,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }
      
      if (attempt < 2) await new Promise(resolve => setTimeout(resolve, 1000));
    }
    
    if (!baseImage) throw new Error(`Failed to generate image after 3 attempts. Last error: ${lastError}`);

    console.log('Step 3: Adding watermark via AI edit...');
    
    const watermarkPrompt = `Resize this image to exactly 640x360 pixels (16:9 aspect ratio).

THEN add a professional watermark with these EXACT specifications:

WATERMARK REQUIREMENTS:
- Position: TOP-LEFT corner, approximately 2% from the left and top edges
- Text: "Pavlova Psy SPB" (exactly this text)
- Background: Semi-transparent dark rounded rectangle (pill shape) behind the text
- Text color: White, 90% opacity
- Size: Small and subtle, about 3-4% of the image height
- Style: Modern, professional, non-intrusive

OUTPUT REQUIREMENTS:
- Format: JPEG
- Resolution: exactly 640x360 pixels`;

    let imageWithWatermark = baseImage;
    
    try {
      const editResponse = await fetch("https://ai.gateway.lovable.dev/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${LOVABLE_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "google/gemini-2.5-flash-image-preview",
          messages: [{
            role: "user",
            content: [
              { type: "text", text: watermarkPrompt },
              { type: "image_url", image_url: { url: baseImage } }
            ]
          }],
          modalities: ["image", "text"]
        }),
      });

      if (editResponse.ok) {
        const editData = await editResponse.json();
        const editedImage = editData.choices?.[0]?.message?.images?.[0]?.image_url?.url;
        
        if (editedImage && editedImage.startsWith('data:image/')) {
          imageWithWatermark = editedImage;
        }
      }
    } catch (editError) {
      console.warn('Watermark edit failed, using base image');
    }

    console.log('Step 4: Programmatic compression...');
    
    const compressedBytes = await compressImage(
      imageWithWatermark,
      MAX_BINARY_SIZE_KB,
      TARGET_WIDTH,
      TARGET_HEIGHT
    );
    
    const finalSizeKB = Math.round(compressedBytes.length / 1024);

    console.log('Step 5: Uploading to storage...');

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const fileName = `${articleId || crypto.randomUUID()}_${Date.now()}.jpg`;
    
    const { error: uploadError } = await supabase.storage
      .from('article-images')
      .upload(fileName, compressedBytes, { 
        contentType: 'image/jpeg', 
        upsert: true 
      });

    if (uploadError) throw new Error(`Failed to upload image: ${uploadError.message}`);

    const { data: { publicUrl } } = supabase.storage
      .from('article-images')
      .getPublicUrl(fileName);

    return new Response(JSON.stringify({ 
      success: true, 
      imageUrl: publicUrl,
      sizeKB: finalSizeKB,
      usedDeepAnalysis: usedAnalysis
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });

  } catch (error) {
    console.error('Image generation error:', error);
    return new Response(JSON.stringify({ 
      error: error instanceof Error ? error.message : 'Failed to generate image' 
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});
```

### Функция 4: publish-to-bitrix

Файл: supabase/functions/publish-to-bitrix/index.ts

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const MAX_PAYLOAD_KB = 900;

async function fetchImageAsBase64(imageUrl: string): Promise<string | null> {
  try {
    const response = await fetch(imageUrl);
    if (!response.ok) return null;
    
    const contentType = response.headers.get('content-type') || 'image/jpeg';
    const arrayBuffer = await response.arrayBuffer();
    const bytes = new Uint8Array(arrayBuffer);
    
    let binary = '';
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    const base64 = btoa(binary);
    
    return `data:${contentType};base64,${base64}`;
  } catch (error) {
    console.error('Error fetching image:', error);
    return null;
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { articleId } = await req.json();

    if (!articleId) throw new Error("Article ID is required");

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const { data: article, error: articleError } = await supabase
      .from('articles')
      .select('*, category:categories(name, bitrix_id)')
      .eq('id', articleId)
      .single();

    if (articleError || !article) throw new Error(`Article not found: ${articleError?.message}`);

    const { data: settings } = await supabase
      .from('app_settings')
      .select('key, value')
      .in('key', ['bitrix_api_url', 'bitrix_api_key', 'bitrix_infoblock_id']);

    const settingsMap: Record<string, string> = {};
    settings?.forEach(s => {
      settingsMap[s.key] = typeof s.value === 'string' ? s.value : String(s.value);
    });

    const bitrixUrl = settingsMap['bitrix_api_url'];
    const bitrixApiKey = settingsMap['bitrix_api_key'];
    const infoblockId = settingsMap['bitrix_infoblock_id'];

    if (!bitrixUrl || !bitrixApiKey) throw new Error("Bitrix API settings not configured");

    const cleanApiKey = bitrixApiKey.replace(/"/g, '').trim();

    const categoryName = article.category?.name || null;
    
    const bitrixData: Record<string, unknown> = {
      title: article.title,
      detail_text: article.html_content || article.content,
      preview_text: '',
      blog_tab: categoryName,
      iblock_id: infoblockId || null,
    };

    let imageIncluded = false;
    if (article.image_url) {
      const imageBase64 = await fetchImageAsBase64(article.image_url);
      
      if (imageBase64) {
        const testPayload = JSON.stringify({ ...bitrixData, preview_picture_base64: imageBase64 });
        const payloadSizeKB = Math.round(testPayload.length / 1024);
        
        if (payloadSizeKB <= MAX_PAYLOAD_KB) {
          bitrixData.preview_picture_base64 = imageBase64;
          bitrixData.detail_picture_base64 = imageBase64;
          imageIncluded = true;
        }
      }
    }

    const payloadStr = JSON.stringify(bitrixData);

    const publishResponse = await fetch(bitrixUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Token': cleanApiKey,
      },
      body: payloadStr,
    });

    const responseText = await publishResponse.text();

    let responseData;
    try { responseData = JSON.parse(responseText); } catch { responseData = { raw: responseText }; }

    if (!publishResponse.ok) throw new Error(`Bitrix API error: ${publishResponse.status} - ${responseText}`);

    await supabase.from('published_articles').insert({
      article_id: articleId,
      bitrix_id: responseData.id || responseData.bitrix_id || null,
      action: 'create',
      response: responseData,
    });

    await supabase.from('articles').update({ status: 'published' }).eq('id', articleId);

    return new Response(JSON.stringify({
      success: true,
      bitrix_id: responseData.id || responseData.bitrix_id,
      message: 'Article published successfully',
      image_included: imageIncluded,
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });

  } catch (error) {
    console.error('Publish error:', error);
    return new Response(JSON.stringify({
      error: error instanceof Error ? error.message : 'Failed to publish article',
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});
```

### Функция 5: publish-review-to-bitrix

Файл: supabase/functions/publish-review-to-bitrix/index.ts

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const MAX_PAYLOAD_KB = 900;

async function fetchImageAsBase64(imageUrl: string): Promise<string | null> {
  try {
    const response = await fetch(imageUrl);
    if (!response.ok) return null;
    
    const contentType = response.headers.get('content-type') || 'image/jpeg';
    const arrayBuffer = await response.arrayBuffer();
    const bytes = new Uint8Array(arrayBuffer);
    
    let binary = '';
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    const base64 = btoa(binary);
    
    return `data:${contentType};base64,${base64}`;
  } catch (error) {
    console.error('Error fetching image:', error);
    return null;
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { reviewId } = await req.json();

    if (!reviewId) throw new Error("Review ID is required");

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const { data: review, error: reviewError } = await supabase
      .from('reviews')
      .select('*')
      .eq('id', reviewId)
      .single();

    if (reviewError || !review) throw new Error(`Review not found: ${reviewError?.message}`);

    const { data: settings } = await supabase
      .from('app_settings')
      .select('key, value')
      .in('key', ['bitrix_reviews_api_url', 'bitrix_reviews_api_key', 'bitrix_reviews_infoblock_id']);

    const settingsMap: Record<string, string> = {};
    settings?.forEach(s => {
      settingsMap[s.key] = typeof s.value === 'string' ? s.value : String(s.value);
    });

    const bitrixUrl = settingsMap['bitrix_reviews_api_url'];
    const bitrixApiKey = settingsMap['bitrix_reviews_api_key'];

    if (!bitrixUrl || !bitrixApiKey) throw new Error("Bitrix API settings for reviews not configured");

    const cleanApiKey = bitrixApiKey.replace(/"/g, '').trim();

    const bitrixData: Record<string, unknown> = {
      title: review.title || 'Отзыв от ' + new Date().toLocaleDateString('ru-RU'),
      preview_text: review.description || '',
      detail_text: review.description || '',
    };

    let previewIncluded = false;
    let detailIncluded = false;
    
    if (review.image_url) {
      const previewBase64 = await fetchImageAsBase64(review.image_url);
      if (previewBase64) {
        const testPayload = JSON.stringify({ ...bitrixData, preview_picture_base64: previewBase64 });
        if (Math.round(testPayload.length / 1024) <= MAX_PAYLOAD_KB) {
          bitrixData.preview_picture_base64 = previewBase64;
          previewIncluded = true;
        }
      }
    }
    
    const originalUrl = review.original_image_url || review.image_url;
    if (originalUrl) {
      const originalBase64 = await fetchImageAsBase64(originalUrl);
      if (originalBase64) {
        const testPayload = JSON.stringify({ ...bitrixData, detail_picture_base64: originalBase64 });
        if (Math.round(testPayload.length / 1024) <= MAX_PAYLOAD_KB) {
          bitrixData.detail_picture_base64 = originalBase64;
          detailIncluded = true;
        }
      }
    }

    const payloadStr = JSON.stringify(bitrixData);

    const publishResponse = await fetch(bitrixUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Token': cleanApiKey,
      },
      body: payloadStr,
    });

    const responseText = await publishResponse.text();

    let responseData;
    try { responseData = JSON.parse(responseText); } catch { responseData = { raw: responseText }; }

    if (!publishResponse.ok) throw new Error(`Bitrix API error: ${publishResponse.status} - ${responseText}`);

    await supabase.from('published_reviews').insert({
      review_id: reviewId,
      bitrix_id: responseData.id || responseData.bitrix_id || null,
      action: 'create',
      response: responseData,
    });

    await supabase.from('reviews').update({ status: 'published' }).eq('id', reviewId);

    return new Response(JSON.stringify({
      success: true,
      bitrix_id: responseData.id || responseData.bitrix_id,
      message: 'Review published successfully',
      preview_included: previewIncluded,
      detail_included: detailIncluded,
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });

  } catch (error) {
    console.error('Publish error:', error);
    return new Response(JSON.stringify({
      error: error instanceof Error ? error.message : 'Failed to publish review',
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});
```

### Функция 6: sync-categories

Файл: supabase/functions/sync-categories/index.ts

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const { data: settings } = await supabase
      .from('app_settings')
      .select('key, value')
      .in('key', ['bitrix_api_url', 'bitrix_api_key']);

    const settingsMap: Record<string, string> = {};
    settings?.forEach(s => {
      settingsMap[s.key] = typeof s.value === 'string' ? s.value.replace(/"/g, '') : String(s.value);
    });

    const apiUrl = settingsMap['bitrix_api_url'];
    const apiKey = settingsMap['bitrix_api_key'];

    if (!apiUrl) {
      return new Response(JSON.stringify({ success: false, error: 'Bitrix API URL not configured' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const categoriesUrl = apiUrl.replace(/blog_post\.php.*$/, 'get_categories.php');
    
    const response = await fetch(categoriesUrl, {
      headers: { 'X-API-Token': apiKey },
    });

    const responseText = await response.text();
    let data;
    try { data = JSON.parse(responseText); } catch { throw new Error(`Invalid JSON response: ${responseText.slice(0, 200)}`); }

    if (!data.success || !data.categories) throw new Error(data.error || 'Failed to fetch categories');

    const { data: localCategories } = await supabase.from('categories').select('id, name, bitrix_id');

    let updated = 0;
    let created = 0;

    for (const bitrixCat of data.categories) {
      const bitrixName = bitrixCat.name?.toLowerCase().trim();
      const bitrixId = parseInt(bitrixCat.id, 10);
      
      const localCat = localCategories?.find((c) => c.name?.toLowerCase().trim() === bitrixName);

      if (localCat) {
        if (localCat.bitrix_id !== bitrixId) {
          await supabase.from('categories').update({ bitrix_id: bitrixId, is_synced: true }).eq('id', localCat.id);
          updated++;
        }
      } else {
        await supabase.from('categories').insert({ name: bitrixCat.name, bitrix_id: bitrixId, is_synced: true });
        created++;
      }
    }

    return new Response(JSON.stringify({ success: true, updated, created, total: data.categories.length }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('Error syncing categories:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return new Response(JSON.stringify({ success: false, error: errorMessage }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
```

### Функция 7: verify-telegram-token

Файл: supabase/functions/verify-telegram-token/index.ts

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { token, registerWebhook } = await req.json();

    if (!token) {
      return new Response(JSON.stringify({ success: false, error: 'Token is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const getMeResponse = await fetch(`https://api.telegram.org/bot${token}/getMe`);
    const getMeData = await getMeResponse.json();

    if (!getMeData.ok) {
      return new Response(JSON.stringify({ success: false, error: getMeData.description || 'Invalid token' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    let webhookStatus = null;

    if (registerWebhook) {
      const supabaseUrl = Deno.env.get('SUPABASE_URL');
      const webhookUrl = `${supabaseUrl}/functions/v1/telegram-webhook`;

      const setWebhookResponse = await fetch(`https://api.telegram.org/bot${token}/setWebhook`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ url: webhookUrl }),
      });
      const setWebhookData = await setWebhookResponse.json();

      if (setWebhookData.ok) {
        webhookStatus = 'registered';

        const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
        if (supabaseUrl && supabaseServiceRoleKey) {
          const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);
          await supabase.from('app_settings').upsert({ key: 'telegram_bot_token', value: token }, { onConflict: 'key' });
        }
      } else {
        webhookStatus = 'failed';
      }
    }

    return new Response(JSON.stringify({ 
      success: true,
      bot: { id: getMeData.result.id, username: getMeData.result.username, firstName: getMeData.result.first_name },
      webhookStatus,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error('Error verifying Telegram token:', error);
    return new Response(JSON.stringify({ success: false, error: error instanceof Error ? error.message : 'Unknown error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
```

### Функция 8: test-bitrix

Файл: supabase/functions/test-bitrix/index.ts

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { url, apiKey } = await req.json();

    if (!url) throw new Error('URL is required');

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Token': apiKey || '',
      },
      body: JSON.stringify({ action: 'test' }),
    });

    const data = await response.json();

    return new Response(JSON.stringify({ success: true, data }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return new Response(JSON.stringify({ success: false, error: errorMessage }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
```

### Функция 9: delete-user

Файл: supabase/functions/delete-user/index.ts

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: 'Unauthorized' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const token = authHeader.replace('Bearer ', '');
    const { data: { user: caller }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !caller) {
      return new Response(JSON.stringify({ success: false, error: 'Invalid token' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: callerRole } = await supabase
      .from('user_roles')
      .select('role')
      .eq('user_id', caller.id)
      .single();

    if (callerRole?.role !== 'admin') {
      return new Response(JSON.stringify({ success: false, error: 'Only admin can delete users' }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { userId } = await req.json();

    if (!userId) {
      return new Response(JSON.stringify({ success: false, error: 'userId is required' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (userId === caller.id) {
      return new Response(JSON.stringify({ success: false, error: 'Cannot delete yourself' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { error: deleteError } = await supabase.auth.admin.deleteUser(userId);

    if (deleteError) {
      return new Response(JSON.stringify({ success: false, error: deleteError.message }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    return new Response(JSON.stringify({ 
      success: false, 
      error: error instanceof Error ? error.message : 'Unknown error' 
    }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
```

### Настройки config.toml

Добавь в supabase/config.toml:

```toml
[functions.telegram-webhook]
verify_jwt = false

[functions.generate-seo]
verify_jwt = false

[functions.generate-image]
verify_jwt = false

[functions.publish-to-bitrix]
verify_jwt = false

[functions.publish-review-to-bitrix]
verify_jwt = false

[functions.sync-categories]
verify_jwt = false

[functions.verify-telegram-token]
verify_jwt = false

[functions.test-bitrix]
verify_jwt = false

[functions.delete-user]
verify_jwt = false
```
```

---

## Этап 3: UI — Типы, компоненты, страницы, роуты

Скопируй и отправь в чат проекта **Irina's Insight Platform**:

---

```
Добавь раздел "Блог" в админ-панель. Используй существующую систему аутентификации (useAuth из @/contexts/AuthContext, isAdmin). НЕ создавай новую auth систему.

## 1. Зависимости

Добавь пакеты TipTap:
- @tiptap/react
- @tiptap/starter-kit
- @tiptap/extension-color
- @tiptap/extension-link
- @tiptap/extension-text-style
- @tiptap/extension-underline

## 2. Типы — создай src/lib/blog-types.ts

```typescript
export interface Category {
  id: string;
  name: string;
  bitrix_id: number | null;
  is_synced: boolean;
  created_at: string;
  updated_at: string;
}

export interface Article {
  id: string;
  title: string;
  content: string;
  html_content: string;
  image_url: string | null;
  category_id: string | null;
  status: 'draft' | 'ready' | 'published';
  meta_title: string | null;
  meta_description: string | null;
  meta_keywords: string | null;
  canonical_url: string | null;
  og_title: string | null;
  og_description: string | null;
  og_image: string | null;
  twitter_title: string | null;
  twitter_description: string | null;
  twitter_image: string | null;
  author_id: string;
  telegram_message_id: string | null;
  created_at: string;
  updated_at: string;
  category?: Category;
}

export interface Review {
  id: string;
  title: string;
  image_url: string | null;
  original_image_url: string | null;
  description: string | null;
  status: 'draft' | 'ready' | 'published';
  author_id: string;
  telegram_message_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface TelegramWhitelist {
  id: string;
  telegram_id: string;
  name: string | null;
  created_by: string;
  created_at: string;
}

export interface PublishedArticle {
  id: string;
  article_id: string;
  bitrix_id: number | null;
  published_at: string;
  action: 'create' | 'update' | 'delete';
  response: object | null;
}

export interface PublishedReview {
  id: string;
  review_id: string;
  bitrix_id: number | null;
  published_at: string;
  action: 'create' | 'update' | 'delete';
  response: object | null;
}
```

## 3. Компонент RichTextEditor — создай src/components/blog/RichTextEditor.tsx

Визуальный редактор на TipTap с панелью инструментов: жирный, курсив, подчёркивание, заголовки H2/H3, маркированный/нумерованный списки, ссылки, горизонтальная линия, отмена/повтор, очистка форматирования.

Полный код:

```tsx
import { useEditor, EditorContent } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';
import Link from '@tiptap/extension-link';
import Underline from '@tiptap/extension-underline';
import { TextStyle } from '@tiptap/extension-text-style';
import Color from '@tiptap/extension-color';
import { Button } from '@/components/ui/button';
import { 
  Bold, Italic, Underline as UnderlineIcon, 
  Link as LinkIcon, List, ListOrdered, Heading2, Heading3,
  Undo, Redo, RemoveFormatting, Minus
} from 'lucide-react';
import { useEffect } from 'react';

interface RichTextEditorProps {
  content: string;
  onChange: (html: string) => void;
}

export function RichTextEditor({ content, onChange }: RichTextEditorProps) {
  const editor = useEditor({
    extensions: [
      StarterKit.configure({ heading: { levels: [1, 2, 3] } }),
      Link.configure({ openOnClick: false, HTMLAttributes: { class: 'text-primary underline' } }),
      Underline,
      TextStyle,
      Color,
    ],
    content,
    onUpdate: ({ editor }) => { onChange(editor.getHTML()); },
    editorProps: {
      attributes: { class: 'prose prose-sm max-w-none p-4 min-h-[400px] focus:outline-none' },
    },
  });

  useEffect(() => {
    if (editor && content !== editor.getHTML()) {
      editor.commands.setContent(content);
    }
  }, [content, editor]);

  if (!editor) return null;

  const setLink = () => {
    const previousUrl = editor.getAttributes('link').href;
    const url = window.prompt('URL ссылки:', previousUrl);
    if (url === null) return;
    if (url === '') { editor.chain().focus().extendMarkRange('link').unsetLink().run(); return; }
    editor.chain().focus().extendMarkRange('link').setLink({ href: url }).run();
  };

  return (
    <div className="border rounded-md overflow-hidden">
      <div className="flex flex-wrap gap-1 p-2 border-b bg-muted/30">
        <Button type="button" variant="ghost" size="sm" onClick={() => editor.chain().focus().undo().run()} disabled={!editor.can().undo()} title="Отменить"><Undo className="w-4 h-4" /></Button>
        <Button type="button" variant="ghost" size="sm" onClick={() => editor.chain().focus().redo().run()} disabled={!editor.can().redo()} title="Повторить"><Redo className="w-4 h-4" /></Button>
        <div className="w-px h-6 bg-border mx-1" />
        <Button type="button" variant={editor.isActive('bold') ? 'secondary' : 'ghost'} size="sm" onClick={() => editor.chain().focus().toggleBold().run()} title="Жирный"><Bold className="w-4 h-4" /></Button>
        <Button type="button" variant={editor.isActive('italic') ? 'secondary' : 'ghost'} size="sm" onClick={() => editor.chain().focus().toggleItalic().run()} title="Курсив"><Italic className="w-4 h-4" /></Button>
        <Button type="button" variant={editor.isActive('underline') ? 'secondary' : 'ghost'} size="sm" onClick={() => editor.chain().focus().toggleUnderline().run()} title="Подчёркивание"><UnderlineIcon className="w-4 h-4" /></Button>
        <div className="w-px h-6 bg-border mx-1" />
        <Button type="button" variant={editor.isActive('heading', { level: 2 }) ? 'secondary' : 'ghost'} size="sm" onClick={() => editor.chain().focus().toggleHeading({ level: 2 }).run()} title="Заголовок 2"><Heading2 className="w-4 h-4" /></Button>
        <Button type="button" variant={editor.isActive('heading', { level: 3 }) ? 'secondary' : 'ghost'} size="sm" onClick={() => editor.chain().focus().toggleHeading({ level: 3 }).run()} title="Заголовок 3"><Heading3 className="w-4 h-4" /></Button>
        <div className="w-px h-6 bg-border mx-1" />
        <Button type="button" variant={editor.isActive('bulletList') ? 'secondary' : 'ghost'} size="sm" onClick={() => editor.chain().focus().toggleBulletList().run()} title="Маркированный список"><List className="w-4 h-4" /></Button>
        <Button type="button" variant={editor.isActive('orderedList') ? 'secondary' : 'ghost'} size="sm" onClick={() => editor.chain().focus().toggleOrderedList().run()} title="Нумерованный список"><ListOrdered className="w-4 h-4" /></Button>
        <div className="w-px h-6 bg-border mx-1" />
        <Button type="button" variant={editor.isActive('link') ? 'secondary' : 'ghost'} size="sm" onClick={setLink} title="Ссылка"><LinkIcon className="w-4 h-4" /></Button>
        <Button type="button" variant="ghost" size="sm" onClick={() => editor.chain().focus().setHorizontalRule().run()} title="Разделитель"><Minus className="w-4 h-4" /></Button>
        <div className="w-px h-6 bg-border mx-1" />
        <Button type="button" variant="ghost" size="sm" onClick={() => editor.chain().focus().unsetAllMarks().clearNodes().run()} title="Очистить форматирование"><RemoveFormatting className="w-4 h-4" /></Button>
      </div>
      <EditorContent editor={editor} />
    </div>
  );
}
```

## 4. Страницы — создай в src/pages/admin/

ВАЖНО при создании страниц:
- НЕ оборачивай в AppLayout — страницы рендерятся внутри <Outlet /> от AdminLayout
- Используй `useAuth` из `@/contexts/AuthContext` (НЕ из `@/hooks/useAuth`)
- `isAdmin` из контекста = полный доступ (эквивалент superadmin в оригинале)
- Все ссылки внутри блога: /admin/blog/articles, /admin/blog/articles/new, /admin/blog/reviews, и т.д.

### 4.1 BlogDashboard.tsx

Дашборд со статистикой: всего статей, черновики, готовы, опубликовано, всего отзывов, опубликовано отзывов. Карточки-счётчики в сетке. Внизу — список последних 5 статей с ссылками на /admin/blog/articles/{id} для редактирования. Кнопка "Новая статья" ведёт на /admin/blog/articles/new.

Данные берутся из таблиц articles (select status) и reviews (select status).

### 4.2 BlogArticles.tsx

Список статей с фильтрами:
- Поиск по названию
- Фильтр по статусу (все/черновики/готовы/опубликованы)
- Фильтр по категории (из таблицы categories)
- Переключатель "Автопубликация" (app_settings key='auto_publish_enabled')

Карточки с:
- Превью изображения (image_url)
- Названием (title)
- Статусом (draft/ready/published) с иконками Clock/CheckCircle/Send
- Категорией
- Датой обновления

Кнопка "Новая статья" → /admin/blog/articles/new
Клик по карточке → /admin/blog/articles/{id}

### 4.3 BlogArticleEditor.tsx

Полный редактор статьи. Путь: /admin/blog/articles/new и /admin/blog/articles/:id

Левая часть (2/3):
- Заголовок (input)
- Категория (select из таблицы categories)
- Изображение (input URL + кнопка AI-генерации через supabase.functions.invoke('generate-image'))
- Контент: переключатель Визуальный/HTML. В визуальном — RichTextEditor из @/components/blog/RichTextEditor. В HTML — textarea.

Правая панель (1/3):
- SEO блок (meta_title, meta_description, meta_keywords, canonical_url) + кнопка "AI" для генерации через generate-seo
- Open Graph блок (og_title, og_description, og_image)
- Превью изображения

Кнопки:
- Сохранить (как черновик)
- Опубликовать (supabase.functions.invoke('publish-to-bitrix', { body: { articleId } }))
- Удалить (только если isAdmin)
- Назад → /admin/blog/articles

### 4.4 BlogReviews.tsx

Грид отзывов с превью изображений.
- Фильтр по статусу
- Кнопка "Добавить" → /admin/blog/reviews/new
- Карточки: изображение (aspect-ratio 4/3), дата, статус badge
- Hover-действия: редактировать (/admin/blog/reviews/{id}), опубликовать (publish-review-to-bitrix), удалить (с AlertDialog, только если isAdmin)

### 4.5 BlogReviewEditor.tsx

Путь: /admin/blog/reviews/new и /admin/blog/reviews/:id

Две колонки:
- Слева: загрузка изображения (в storage bucket review-images), превью
- Справа: заголовок (input), описание (textarea), кнопка удалить (AlertDialog, только isAdmin)

Кнопки вверху:
- Готов (status → ready)
- Опубликовать (publish-review-to-bitrix)
- Сохранить
- Назад → /admin/blog/reviews

### 4.6 BlogCategories.tsx

CRUD категорий:
- Форма добавления (input + кнопка)
- Список с inline-редактированием (клик Edit → input, Enter → сохранить)
- Кнопка удаления
- Badge "Битрикс" для синхронизированных (is_synced)
- Кнопка "Загрузить из Битрикс" → supabase.functions.invoke('sync-categories')

### 4.7 BlogSettings.tsx

Вкладки (Tabs): Общие, Telegram, Битрикс, Пользователи.

Вкладка Telegram:
- Токен бота (input type=password)
- Кнопка "Проверить" → supabase.functions.invoke('verify-telegram-token', { body: { token, registerWebhook: true } })
- Отображение информации о боте (username, webhook status)
- Белый список Telegram ID: добавление (input ID + input имя), список с кнопками удаления

Вкладка Битрикс:
- Настройки статей: URL API, API ключ, ID инфоблока, кнопка "Проверить подключение" (test-bitrix)
- Настройки отзывов: отдельные URL/ключ/инфоблок, переключатель "Автопубликация отзывов" (auto_publish_reviews), кнопка проверки

Вкладка Пользователи:
- Переключатель "Регистрация новых администраторов" (registration_enabled)
- Список администраторов (user_roles + profiles), с кнопкой удаления (delete-user, только если isAdmin и не себя)

Все настройки сохраняются в app_settings через upsert. Кнопка "Сохранить" вверху страницы.

## 5. Роуты в App.tsx

Внутри блока `<Route path="/admin" ...>` добавь вложенные роуты:

```tsx
<Route path="blog" element={<BlogDashboard />} />
<Route path="blog/articles" element={<BlogArticles />} />
<Route path="blog/articles/new" element={<BlogArticleEditor />} />
<Route path="blog/articles/:id" element={<BlogArticleEditor />} />
<Route path="blog/reviews" element={<BlogReviews />} />
<Route path="blog/reviews/new" element={<BlogReviewEditor />} />
<Route path="blog/reviews/:id" element={<BlogReviewEditor />} />
<Route path="blog/categories" element={<BlogCategories />} />
<Route path="blog/settings" element={<BlogSettings />} />
```

## 6. Меню в AdminSidebar.tsx

Добавь пункты меню после существующих:

```typescript
{ title: "Блог", url: "/admin/blog", icon: FileText },
{ title: "Статьи", url: "/admin/blog/articles", icon: FileText },
{ title: "Отзывы", url: "/admin/blog/reviews", icon: MessageSquare },
{ title: "Категории", url: "/admin/blog/categories", icon: Tags },
{ title: "Настройки блога", url: "/admin/blog/settings", icon: Settings },
```

Импорты: FileText, MessageSquare, Tags, Settings из lucide-react.
```

---

## Этап 4: Миграция данных

Скопируй и отправь в чат проекта **Irina's Insight Platform** после завершения этапов 1-3:

---

```
Создай Edge Function "import-blog-data" для импорта существующих статей, отзывов и категорий из другого проекта.

Файл: supabase/functions/import-blog-data/index.ts

Функция:
1. Принимает POST с JSON: { articles: [...], reviews: [...], categories: [...] }
2. Для categories: upsert по имени (если категория с таким именем существует — пропустить)
3. Для articles: вставляет все записи, маппит category_id по имени категории
4. Для reviews: вставляет все записи
5. Возвращает: { imported_categories, imported_articles, imported_reviews }

verify_jwt = false в config.toml.

ВАЖНО: Для author_id используй первого admin из user_roles.
```

---

## Замечания

1. **Этапы 1 и 2** можно отправлять одним промтом если помещается
2. **Этап 3** — самый большой, возможно потребуется разбить на подэтапы (сначала типы + компонент, потом страницы, потом роуты)
3. **Telegram webhook** можно зарегистрировать только на один URL. Для параллельной работы переключайте webhook между проектами через настройки
4. **Настройки Bitrix** (URL, ключи) нужно заполнить заново в целевом проекте через UI настроек блога
