importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js");

firebase.initializeApp({
    apiKey: "AIzaSyAjqOSEXlHBKaHXpXFNbKUlGQdPqOhFQPE",
    authDomain: "masjidadmin-8f9a7.firebaseapp.com",
    projectId: "masjidadmin-8f9a7",
    storageBucket: "masjidadmin-8f9a7.firebasestorage.app",
    messagingSenderId: "1055933663374",
    appId: "1:1055933663374:web:c1b4c0e8d7e4e5f6a7b8c9",
    measurementId: "G-XXXXXXXXXX"
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);

    const notificationTitle = payload.notification?.title || 'New Notification';
    const notificationOptions = {
        body: payload.notification?.body || '',
        icon: '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});
