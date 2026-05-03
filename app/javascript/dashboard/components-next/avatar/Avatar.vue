<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { removeEmoji } from 'shared/helpers/emoji';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import ChannelIcon from 'dashboard/components-next/icon/ChannelIcon.vue';
import { getInboxBadgePresentation } from 'dashboard/helper/inbox';
import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  src: {
    type: String,
    default: '',
  },
  name: {
    type: String,
    required: true,
  },
  size: {
    type: Number,
    default: 32,
  },
  allowUpload: {
    type: Boolean,
    default: false,
  },
  roundedFull: {
    type: Boolean,
    default: false,
  },
  status: {
    type: String,
    default: null,
    validator: value =>
      !value || wootConstants.AVAILABILITY_STATUS_KEYS.includes(value),
  },
  inbox: {
    type: Object,
    default: null,
  },
  iconName: {
    type: String,
    default: null,
  },
  hideOfflineStatus: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['upload', 'delete']);

const { t } = useI18n();

const isImageValid = ref(true);
const fileInput = ref(null);

const AVATAR_COLORS = {
  dark: [
    ['#4B143D', '#FF8DCC'],
    ['#3F220D', '#FFA366'],
    ['#2A2A2A', '#ADB1B8'],
    ['#023B37', '#0BD8B6'],
    ['#27264D', '#A19EFF'],
    ['#1D2E62', '#9EB1FF'],
  ],
  light: [
    ['#FBDCEF', '#C2298A'],
    ['#FFE0BB', '#99543A'],
    ['#E8E8E8', '#60646C'],
    ['#CCF3EA', '#008573'],
    ['#EBEBFE', '#4747C2'],
    ['#E1E9FF', '#3A5BC7'],
  ],
  default: { bg: '#E8E8E8', text: '#60646C' },
};

const STATUS_CLASSES = computed(() => ({
  online: 'bg-n-teal-10',
  busy: 'bg-n-amber-10',
  ...(props.hideOfflineStatus ? {} : { offline: 'bg-n-slate-10' }),
}));

const showDefaultAvatar = computed(() => !props.src && !props.name);

const initials = computed(() => {
  if (!props.name) return '';
  const words = removeEmoji(props.name).split(/\s+/);
  return words.length === 1
    ? words[0].charAt(0).toUpperCase()
    : words
        .slice(0, 2)
        .map(word => word.charAt(0))
        .join('')
        .toUpperCase();
});

const getColorsByNameLength = computed(() => {
  if (!props.name) return AVATAR_COLORS.default;

  const index = props.name.length % AVATAR_COLORS.light.length;
  return {
    bg: AVATAR_COLORS.light[index][0],
    darkBg: AVATAR_COLORS.dark[index][0],
    text: AVATAR_COLORS.light[index][1],
    darkText: AVATAR_COLORS.dark[index][1],
  };
});

const containerStyles = computed(() => ({
  width: `${props.size}px`,
  height: `${props.size}px`,
}));

const borderRadiusClass = computed(() => {
  if (props.roundedFull) {
    return 'rounded-full';
  }

  // Approximates 25% of size
  if (props.size <= 16) return 'rounded'; // 4px
  if (props.size <= 24) return 'rounded-md'; // 6px
  if (props.size <= 32) return 'rounded-lg'; // 8px
  if (props.size <= 48) return 'rounded-xl'; // 12px
  return 'rounded-2xl'; // 16px
});

const avatarStyles = computed(() => ({
  ...containerStyles.value,
  backgroundColor:
    !showDefaultAvatar.value && (!props.src || !isImageValid.value)
      ? getColorsByNameLength.value.bg
      : undefined,
  color:
    !showDefaultAvatar.value && (!props.src || !isImageValid.value)
      ? getColorsByNameLength.value.text
      : undefined,
  '--dark-bg': getColorsByNameLength.value.darkBg,
  '--dark-text': getColorsByNameLength.value.darkText,
}));

/** Small corner badge (presence or inbox); RTL via insetInline* */
const cornerBadgePx = computed(() =>
  Math.round(Math.max(props.size * 0.44, 12))
);

const cornerOffset = computed(() => {
  const s = cornerBadgePx.value;
  return `${-Math.max(Math.round(s * 0.15), 2)}px`;
});

const statusBadgePositionStyles = computed(() => {
  const d = `${cornerBadgePx.value}px`;
  const o = cornerOffset.value;
  const base = { width: d, height: d };
  if (!props.inbox) {
    return { ...base, bottom: o, insetInlineEnd: o };
  }
  return { ...base, top: o, insetInlineStart: o };
});

const inboxBadgePositionStyles = computed(() => {
  const d = `${cornerBadgePx.value}px`;
  const o = cornerOffset.value;
  return { width: d, height: d, bottom: o, insetInlineEnd: o };
});

const inboxBadgePresentation = computed(() =>
  props.inbox ? getInboxBadgePresentation(props.inbox) : null
);

const inboxBadgeStyle = computed(() => ({
  ...inboxBadgePositionStyles.value,
  ...(inboxBadgePresentation.value?.backgroundColor
    ? { backgroundColor: inboxBadgePresentation.value.backgroundColor }
    : {}),
}));

const iconStyles = computed(() => ({
  fontSize: `${props.size / 1.6}px`,
}));

const initialsStyles = computed(() => ({
  fontSize: `${Math.min(props.size / 2.5, 24)}px`,
}));

const invalidateCurrentImage = () => {
  isImageValid.value = false;
};

const handleUploadAvatar = () => {
  fileInput.value.click();
};

const handleImageUpload = event => {
  const [file] = event.target.files;
  if (file) {
    emit('upload', {
      file,
      url: file ? URL.createObjectURL(file) : null,
    });
  }
};

const handleDeleteAvatar = () => {
  if (fileInput.value) {
    fileInput.value.value = null;
  }
  emit('delete');
};

const handleDismiss = event => {
  event.stopPropagation();
  handleDeleteAvatar();
};

watch(
  () => props.src,
  () => {
    isImageValid.value = true;
  }
);
</script>

<template>
  <span
    class="relative inline-flex group/avatar z-0 flex-shrink-0 align-middle"
    :style="containerStyles"
  >
    <!-- Status + inbox: presence top-leading, channel bottom-trailing (conversation list / design preview parity) -->
    <slot name="badge" :size="size">
      <div
        v-if="status && STATUS_CLASSES[status]"
        class="absolute z-20 border rounded-full border-n-glass-pane"
        :style="statusBadgePositionStyles"
        :class="STATUS_CLASSES[status]"
      />
      <div
        v-if="inbox"
        :style="inboxBadgeStyle"
        class="absolute z-[21] flex items-center justify-center rounded-full shrink-0 p-0.5 border"
        :class="
          inboxBadgePresentation?.useNeutralChrome
            ? 'bg-n-glass-strong border-n-border-glass-soft'
            : 'border-white/20 shadow-sm'
        "
      >
        <ChannelIcon
          :inbox="inbox"
          class="size-full"
          :class="inboxBadgePresentation?.iconClass || 'text-n-text-body'"
        />
      </div>
    </slot>

    <!-- Delete Avatar Button -->
    <div
      v-if="src && allowUpload"
      class="absolute z-20 flex items-center justify-center invisible w-6 h-6 transition-all duration-300 ease-in-out opacity-0 cursor-pointer outline outline-1 outline-n-border-glass-soft -top-2 ltr:-right-2 rtl:-left-2 rounded-full bg-n-glass-strong backdrop-blur-glass-rail backdrop-saturate-glass shadow-pill-soft group-hover/avatar:visible group-hover/avatar:opacity-100"
      @click="handleDismiss"
    >
      <Icon icon="i-lucide-x" class="text-n-text-body size-4" />
    </div>

    <!-- Avatar Container -->
    <span
      role="img"
      class="relative inline-flex items-center justify-center object-cover overflow-hidden font-medium outline outline-1 -outline-offset-1 outline-[rgb(0_0_0_/_0.03)] dark:outline-[rgb(255_255_255_/_0.04)]"
      :class="[
        borderRadiusClass,
        {
          'dark:!bg-[var(--dark-bg)] dark:!text-[var(--dark-text)]':
            !showDefaultAvatar && (!src || !isImageValid),
          'bg-n-slate-3 dark:bg-n-slate-4': showDefaultAvatar,
        },
      ]"
      :style="avatarStyles"
    >
      <!-- Avatar Content -->
      <img
        v-if="src && isImageValid"
        :src="src"
        :alt="name"
        @error="invalidateCurrentImage"
      />

      <template v-else>
        <!-- Custom Icon -->
        <Icon v-if="iconName" :icon="iconName" :style="iconStyles" />

        <!-- Initials -->
        <span
          v-else-if="!showDefaultAvatar"
          :style="initialsStyles"
          class="select-none"
        >
          {{ initials }}
        </span>

        <!-- Fallback Icon if no name or image -->
        <Icon
          v-else
          :title="t('THUMBNAIL.AUTHOR.NOT_AVAILABLE')"
          icon="i-lucide-user"
          :style="iconStyles"
        />
      </template>

      <!-- Upload Overlay and Input -->
      <slot
        v-if="allowUpload || $slots.overlay"
        name="overlay"
        :size="size"
        :handle-upload="handleUploadAvatar"
        :file-input-ref="fileInput"
        :handle-image-upload="handleImageUpload"
      >
        <div
          class="absolute inset-0 z-10 flex items-center justify-center invisible w-full h-full transition-all duration-300 ease-in-out opacity-0 bg-n-alpha-black1 group-hover/avatar:visible group-hover/avatar:opacity-100"
          :class="borderRadiusClass"
          @click="handleUploadAvatar"
        >
          <Icon
            icon="i-lucide-upload"
            class="text-white"
            :style="{ width: `${size / 2}px`, height: `${size / 2}px` }"
          />
          <input
            v-if="allowUpload"
            ref="fileInput"
            type="file"
            accept="image/png, image/jpeg, image/jpg, image/gif, image/webp"
            class="hidden"
            @change="handleImageUpload"
          />
        </div>
      </slot>
    </span>
  </span>
</template>
