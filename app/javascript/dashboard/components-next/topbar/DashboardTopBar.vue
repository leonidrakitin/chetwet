<script setup>
import SidebarAccountSwitcher from 'dashboard/components-next/sidebar/SidebarAccountSwitcher.vue';
import SidebarProfileMenu from 'dashboard/components-next/sidebar/SidebarProfileMenu.vue';
import NotificationsPanel from 'dashboard/components-next/topbar/NotificationsPanel.vue';
import Logo from 'next/icon/Logo.vue';

const emit = defineEmits(['showCreateAccountModal', 'openKeyShortcutModal']);
</script>

<template>
  <header
    class="relative z-50 flex items-center gap-2 px-3 py-2 min-h-0 flex-shrink-0"
  >
    <div
      class="inline-flex items-center gap-2 pl-1.5 pr-2.5 py-1 rounded-pill bg-n-glass-strong border border-n-border-glass backdrop-blur-glass-rail backdrop-saturate-glass shadow-pill-soft min-w-0 max-w-[280px]"
    >
      <span
        class="grid flex-shrink-0 place-content-center size-8 rounded-full bg-n-brand/10 text-n-blue-11"
      >
        <Logo class="size-4" />
      </span>
      <SidebarAccountSwitcher
        class="flex-grow min-w-0"
        @show-create-account-modal="emit('showCreateAccountModal')"
      />
    </div>

    <div class="flex-1" />

    <NotificationsPanel />

    <div
      class="inline-flex items-center rounded-pill bg-n-glass-strong border border-n-border-glass backdrop-blur-glass-rail backdrop-saturate-glass shadow-pill-soft p-1"
    >
      <SidebarProfileMenu
        dropdown-position="top"
        @open-key-shortcut-modal="emit('openKeyShortcutModal')"
      />
    </div>
  </header>
</template>
