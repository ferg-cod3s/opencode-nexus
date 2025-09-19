<script lang="ts">
    import { activityStore } from '../stores/activity';
    import { onMount } from 'svelte';

    let messages: ActivityMessage[] = [];
    let activityList: HTMLElement;
    let selectedIndex = -1;

    onMount(() => {
        const unsubscribe = activityStore.subscribe(value => {
            messages = value;
            // Announce new messages to screen readers
            if (value.length > 0 && messages.length !== value.length) {
                announceNewMessage(value[0]);
            }
        });

        return unsubscribe;
    });

    function announceNewMessage(message: ActivityMessage) {
        const announcement = `${message.type} message: ${message.message}`;
        const liveRegion = document.createElement('div');
        liveRegion.setAttribute('aria-live', 'assertive');
        liveRegion.setAttribute('aria-atomic', 'true');
        liveRegion.style.position = 'absolute';
        liveRegion.style.left = '-10000px';
        liveRegion.style.width = '1px';
        liveRegion.style.height = '1px';
        liveRegion.style.overflow = 'hidden';
        liveRegion.textContent = announcement;
        document.body.appendChild(liveRegion);
        setTimeout(() => document.body.removeChild(liveRegion), 1000);
    }

    function handleKeydown(event: KeyboardEvent) {
        if (messages.length === 0) return;

        switch (event.key) {
            case 'ArrowDown':
                event.preventDefault();
                selectedIndex = Math.min(selectedIndex + 1, messages.length - 1);
                scrollToSelected();
                break;
            case 'ArrowUp':
                event.preventDefault();
                selectedIndex = Math.max(selectedIndex - 1, 0);
                scrollToSelected();
                break;
            case 'Home':
                event.preventDefault();
                selectedIndex = 0;
                scrollToSelected();
                break;
            case 'End':
                event.preventDefault();
                selectedIndex = messages.length - 1;
                scrollToSelected();
                break;
            case 'Enter':
            case ' ':
                event.preventDefault();
                if (selectedIndex >= 0) {
                    toggleMessageExpansion(selectedIndex);
                }
                break;
        }
    }

    function scrollToSelected() {
        if (selectedIndex >= 0 && activityList) {
            const selectedItem = activityList.children[selectedIndex] as HTMLElement;
            if (selectedItem) {
                selectedItem.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
            }
        }
    }

    function toggleMessageExpansion(index: number) {
        // Future enhancement: expand/collapse message details
        console.log('Toggle expansion for message:', index);
    }
</script>

<div
    class="activity-list"
    role="listbox"
    aria-live="polite"
    aria-label="Recent activity messages"
    aria-atomic="false"
    tabindex="0"
    bind:this={activityList}
    on:keydown={handleKeydown}
    aria-activedescendant={selectedIndex >= 0 ? `activity-item-${selectedIndex}` : undefined}
>
    {#each messages as message, index (message.id)}
        <div
            class="activity-item"
            class:error={message.type === 'error'}
            class:success={message.type === 'success'}
            class:selected={index === selectedIndex}
            id="activity-item-{index}"
            role="option"
            aria-selected={index === selectedIndex}
            aria-label="{message.type} message at {message.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}: {message.message}"
            tabindex="-1"
        >
            <span class="activity-time" aria-hidden="true">
                {message.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
            </span>
            <span class="activity-message" aria-hidden="true">
                {message.message}
            </span>
            <span class="sr-only">
                {message.type} message: {message.message}
            </span>
        </div>
    {/each}
    {#if messages.length === 0}
        <div class="activity-item empty" role="option" aria-selected="false" aria-label="No activity messages yet">
            <span class="activity-message">No activity messages yet</span>
        </div>
    {/if}
</div>

<style>
    .activity-list {
        max-height: 200px;
        overflow-y: auto;
        padding-right: 0.5rem;
    }

    .activity-item {
        display: flex;
        gap: 1rem;
        padding: 0.75rem 0;
        border-bottom: 1px solid hsl(0, 0%, 95%);
    }

    .activity-item:last-child {
        border-bottom: none;
    }

    .activity-time {
        min-width: 60px;
        font-size: 0.75rem;
        color: hsl(220, 20%, 60%);
        font-family: monospace;
    }

    .activity-message {
        font-size: 0.875rem;
        color: hsl(220, 20%, 40%);
    }

    .activity-item.error .activity-message {
        color: hsl(0, 70%, 50%);
    }

    .activity-item.success .activity-message {
        color: hsl(120, 50%, 50%);
    }

    .activity-item.selected {
        background: hsl(220, 90%, 98%);
        border-left: 3px solid hsl(220, 90%, 60%);
        outline: 2px solid hsl(220, 90%, 60%);
        outline-offset: -2px;
    }

    .activity-item:focus {
        outline: 2px solid hsl(220, 90%, 60%);
        outline-offset: 2px;
    }

    .activity-item.empty {
        color: hsl(220, 20%, 60%);
        font-style: italic;
    }

    .sr-only {
        position: absolute;
        width: 1px;
        height: 1px;
        padding: 0;
        margin: -1px;
        overflow: hidden;
        clip: rect(0, 0, 0, 0);
        white-space: nowrap;
        border: 0;
    }

    /* High contrast mode support */
    @media (prefers-contrast: high) {
        .activity-item.selected {
            background: hsl(0, 0%, 100%);
            border-left: 4px solid hsl(0, 0%, 0%);
            outline: 2px solid hsl(0, 0%, 0%);
        }

        .activity-item:focus {
            outline: 3px solid hsl(0, 0%, 0%);
        }
    }
</style>