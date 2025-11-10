<script lang="ts">
  import { onMount } from 'svelte';

  onMount(async () => {
    // Service Worker registration only runs in browser (onMount)
    if (typeof window !== 'undefined' && typeof navigator !== 'undefined' && 'serviceWorker' in navigator) {
      try {
        const registration = await navigator.serviceWorker.register('/sw.js');
        console.log('SW registered: ', registration);
      } catch (registrationError) {
        console.log('SW registration failed: ', registrationError);
      }
    }
  });
</script>

<!-- Empty component - only runs onMount hooks in browser -->
