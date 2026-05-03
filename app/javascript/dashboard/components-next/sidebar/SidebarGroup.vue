<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useSidebarContext, usePopoverState } from './provider';
import { useRoute, useRouter } from 'vue-router';
import Policy from 'dashboard/components/policy.vue';
import Icon from 'next/icon/Icon.vue';
import SidebarGroupHeader from './SidebarGroupHeader.vue';
import SidebarCollapsedPopover from './SidebarCollapsedPopover.vue';

const props = defineProps({
  name: { type: String, required: true },
  label: { type: String, required: true },
  icon: { type: [String, Object, Function], default: null },
  to: { type: Object, default: null },
  activeOn: { type: Array, default: () => [] },
  children: { type: Array, default: undefined },
  getterKeys: { type: Object, default: () => ({}) },
});

const {
  resolvePath,
  resolvePermissions,
  resolveFeatureFlag,
  isAllowed,
  isCollapsed,
  isResizing,
} = useSidebarContext();

const {
  activePopover,
  setActivePopover,
  closeActivePopover,
  scheduleClose,
  cancelClose,
} = usePopoverState();

const navigableChildren = computed(() => {
  return props.children?.flatMap(child => child.children || child) || [];
});

const route = useRoute();
const router = useRouter();
const hasChildren = computed(
  () => Array.isArray(props.children) && props.children.length > 0
);

// Use shared popover state - only one popover can be open at a time
const isPopoverOpen = computed(() => activePopover.value === props.name);
const triggerRef = ref(null);
const triggerRect = ref({ top: 0, left: 0, bottom: 0, right: 0 });

const openPopover = () => {
  if (triggerRef.value) {
    const rect = triggerRef.value.getBoundingClientRect();
    triggerRect.value = {
      top: rect.top,
      left: rect.left,
      bottom: rect.bottom,
      right: rect.right,
    };
  }
  setActivePopover(props.name);
};

const closePopover = () => {
  if (activePopover.value === props.name) {
    closeActivePopover();
  }
};

const handleMouseEnter = () => {
  if (!hasChildren.value || isResizing.value) return;
  cancelClose();
  openPopover();
};

const handleMouseLeave = () => {
  if (!hasChildren.value) return;
  scheduleClose(200);
};

const handlePopoverMouseEnter = () => {
  cancelClose();
};

const handlePopoverMouseLeave = () => {
  scheduleClose(100);
};

// Close popover when mouse leaves the window
const handleWindowBlur = () => {
  closeActivePopover();
};

const accessibleItems = computed(() => {
  if (!hasChildren.value) return [];
  return props.children.filter(child => {
    // If a item has no link, it means it's just a subgroup header
    // So we don't need to check for permissions here, because there's nothing to
    // access here anyway
    return child.to && isAllowed(child.to);
  });
});

const hasAccessibleChildren = computed(() => {
  return accessibleItems.value.length > 0;
});

const isActive = computed(() => {
  if (props.to) {
    if (route.path === resolvePath(props.to)) return true;

    return props.activeOn.includes(route.name);
  }

  return false;
});

// We could use the RouterLink isActive too, but our routes are not always
// nested correctly, so we need to check the active state ourselves
// TODO: Audit the routes and fix the nesting and remove this
const activeChild = computed(() => {
  const pathSame = navigableChildren.value.find(
    child => child.to && route.path === resolvePath(child.to)
  );
  if (pathSame) return pathSame;

  // Rank the activeOn Prop higher than the path match
  // There will be cases where the path name is the same but the params are different
  // So we need to rank them based on the params
  // For example, contacts segment list in the sidebar effectively has the same name
  // But the params are different
  const activeOnPages = navigableChildren.value.filter(child =>
    child.activeOn?.includes(route.name)
  );

  if (activeOnPages.length > 0) {
    const rankedPage = activeOnPages.find(child => {
      return Object.keys(child.to.params)
        .map(key => {
          return String(child.to.params[key]) === String(route.params[key]);
        })
        .every(match => match);
    });

    // If there is no ranked page, return the first activeOn page anyway
    // Since this takes higher precedence over the path match
    // This is not perfect, ideally we should rank each route based on all the techniques
    // and then return the highest ranked one
    // But this is good enough for now
    return rankedPage ?? activeOnPages[0];
  }

  return navigableChildren.value.find(
    child => child.to && route.path.startsWith(resolvePath(child.to))
  );
});

const hasActiveChild = computed(() => {
  return activeChild.value !== undefined;
});

const handleTriggerClick = () => {
  if (hasChildren.value && hasAccessibleChildren.value) {
    if (!hasActiveChild.value) {
      const firstItem = accessibleItems.value[0];
      router.push(firstItem.to);
    }
    openPopover();
  }
};

onMounted(() => {
  window.addEventListener('blur', handleWindowBlur);
  document.addEventListener('mouseleave', handleWindowBlur);
});

onUnmounted(() => {
  window.removeEventListener('blur', handleWindowBlur);
  document.removeEventListener('mouseleave', handleWindowBlur);
});
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <Policy
    v-if="!hasChildren || hasAccessibleChildren"
    :permissions="resolvePermissions(to)"
    :feature-flag="resolveFeatureFlag(to)"
    as="li"
    class="text-sm cursor-pointer select-none min-w-0"
  >
    <div
      class="group relative"
      :class="isCollapsed ? 'w-full flex justify-center' : 'w-full'"
      @mouseenter="handleMouseEnter"
      @mouseleave="handleMouseLeave"
    >
      <!-- Collapsed Trigger -->
      <template v-if="isCollapsed">
        <component
          :is="to && !hasChildren ? 'router-link' : 'button'"
          ref="triggerRef"
          :to="to && !hasChildren ? to : undefined"
          type="button"
          class="flex items-center justify-center size-12 rounded-full border backdrop-blur-glass-rail backdrop-saturate-glass transition-all duration-150"
          :class="{
            'text-n-accent-active-fg bg-n-accent-active border-n-accent-active shadow-pill-active':
              isActive || hasActiveChild,
            'text-n-text-body bg-n-glass-soft border-n-border-glass-soft shadow-inset-hairline hover:bg-n-glass-strong hover:border-n-border-glass':
              !isActive && !hasActiveChild,
          }"
          @click="hasChildren ? handleTriggerClick() : null"
        >
          <Icon v-if="icon" :icon="icon" class="size-[18px]" />
        </component>
        <span
          v-if="!hasChildren"
          class="pointer-events-none absolute z-50 ltr:left-[calc(100%+12px)] rtl:right-[calc(100%+12px)] top-1/2 bg-n-accent-active text-n-accent-active-fg px-2.5 py-[5px] rounded-lg text-xs font-medium whitespace-nowrap shadow-pill-active opacity-0 -translate-y-1/2 ltr:-translate-x-1 rtl:translate-x-1 group-hover:opacity-100 group-hover:translate-x-0 group-hover:-translate-y-1/2 transition-[opacity,transform] duration-150"
        >
          {{ label }}
        </span>
      </template>
      <!-- Expanded Trigger -->
      <div v-else ref="triggerRef">
        <SidebarGroupHeader
          :icon
          :name
          :label
          :to
          :getter-keys="getterKeys"
          :is-active="isActive"
          :has-active-child="hasActiveChild"
          :expandable="hasChildren"
          @toggle="handleTriggerClick"
        />
      </div>
      <SidebarCollapsedPopover
        v-if="hasChildren && isPopoverOpen"
        :label="label"
        :children="children"
        :active-child="activeChild"
        :trigger-rect="triggerRect"
        @close="closePopover"
        @mouseenter="handlePopoverMouseEnter"
        @mouseleave="handlePopoverMouseLeave"
      />
    </div>
  </Policy>
</template>
