import { writable } from 'svelte/store';

export interface ActivityMessage {
    id: string;
    timestamp: Date;
    message: string;
    type: 'info' | 'success' | 'warning' | 'error';
}

function createActivityStore() {
    const { subscribe, update } = writable<ActivityMessage[]>([]);

    return {
        subscribe,
        addMessage: (message: string, type: ActivityMessage['type'] = 'info') => {
            const newMessage: ActivityMessage = {
                id: crypto.randomUUID(),
                timestamp: new Date(),
                message,
                type
            };

            update(messages => [newMessage, ...messages].slice(0, 10)); // Keep last 10
        },
        clear: () => update(() => [])
    };
}

export const activityStore = createActivityStore();