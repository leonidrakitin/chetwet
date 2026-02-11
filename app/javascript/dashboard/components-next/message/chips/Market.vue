<script setup>
import { computed } from 'vue';
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  attachment: {
    type: Object,
    required: true,
  },
});

const product = computed(() => {
  const a = props.attachment;
  if (!a) return null;
  const meta = a.meta || {};
  return {
    title: meta.title || a.fallbackTitle || '',
    description: meta.description || '',
    price: meta.priceText || meta.price_text || '',
    thumb: meta.thumbPhoto || meta.thumb_photo || '',
    category: meta.categoryName || meta.category_name || '',
    url: a.dataUrl || meta.marketUrl || meta.market_url || '',
  };
});
</script>

<template>
  <a
    v-if="product.url"
    :href="product.url"
    rel="noreferrer noopener nofollow"
    target="_blank"
    class="flex overflow-hidden rounded-xl border border-n-container bg-n-alpha-white max-w-[280px] hover:border-n-slate-8 transition-colors"
  >
    <div v-if="product.thumb" class="shrink-0 w-20 h-20">
      <img
        :src="product.thumb"
        :alt="product.title"
        class="object-cover w-full h-full"
        loading="lazy"
      />
    </div>
    <div class="flex flex-col min-w-0 flex-1 p-3 gap-1">
      <span class="text-sm font-medium text-n-slate-12 truncate">
        {{ product.title }}
      </span>
      <span v-if="product.price" class="text-sm font-semibold text-n-green-11">
        {{ product.price }}
      </span>
      <p
        v-if="product.description"
        class="text-xs text-n-slate-11 line-clamp-2"
      >
        {{ product.description }}
      </p>
      <span class="mt-1 text-xs text-n-slate-10 flex items-center gap-1">
        <Icon icon="i-lucide-external-link" class="size-3" />
        {{ $t('CONVERSATION.VIEW_PRODUCT') }}
      </span>
    </div>
  </a>
  <div
    v-else
    class="flex overflow-hidden rounded-xl border border-n-container bg-n-alpha-white max-w-[280px] p-3"
  >
    <div
      v-if="product.thumb"
      class="shrink-0 w-16 h-16 rounded-lg overflow-hidden"
    >
      <img
        :src="product.thumb"
        :alt="product.title"
        class="object-cover w-full h-full"
        loading="lazy"
      />
    </div>
    <div class="flex flex-col min-w-0 flex-1 ml-3 gap-1">
      <span class="text-sm font-medium text-n-slate-12 truncate">
        {{ product.title }}
      </span>
      <span v-if="product.price" class="text-sm font-semibold text-n-green-11">
        {{ product.price }}
      </span>
      <p
        v-if="product.description"
        class="text-xs text-n-slate-11 line-clamp-2"
      >
        {{ product.description }}
      </p>
    </div>
  </div>
</template>
