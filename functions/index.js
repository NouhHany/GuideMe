const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendLocationNotification = functions.firestore
  .document('users/{userId}/location/current')
  .onUpdate((change, context) => {
    const newLocation = change.after.data();
    const lat = newLocation.latitude;
    const lng = newLocation.longitude;
    const token = newLocation.fcmToken;

    // Example site: Pyramids (29.9792° N, 31.1342° E)
    if (isNearSite(lat, lng, 29.9792, 31.1342, 2)) {
      const payload = {
        notification: {
          title: "You’re Near the Pyramids!",
          body: "Start your audio tour now."
        },
        token: token
      };
      return admin.messaging().send(payload);
    }
    return null;
  });

exports.scheduleEventNotification = functions.pubsub
  .schedule('every 24 hours')
  .onRun((context) => {
    const eventsRef = admin.firestore().collection('events');
    return eventsRef.where('date', '>', new Date())
      .get()
      .then(snapshot => {
        snapshot.forEach(doc => {
          const payload = {
            notification: {
              title: `Upcoming Event: ${doc.data().name}!`,
              body: doc.data().description
            },
            topic: 'allUsers'
          };
          return admin.messaging().send(payload);
        });
      });
  });

function isNearSite(lat1, lng1, lat2, lng2, km) {
  const R = 6371; // Earth radius in km
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
            Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = R * c;
  return distance <= km;
}

function toRad(degrees) {
  return degrees * Math.PI / 180;
}