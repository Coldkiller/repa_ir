import { initializeApp }from "https://www.gstatic.com/firebasejs/9.6.1/firebase-app.js";
import { getAuth, signInAnonymously, onAuthStateChanged }
from 'https://www.gstatic.com/firebasejs/9.6.1/firebase-auth.js'
import { getFirestore,collection, addDoc,doc, onSnapshot, where, query, enableIndexedDbPersistence }
from 'https://www.gstatic.com/firebasejs/9.6.1/firebase-firestore.js';
const firebaseConfig = {
apiKey: "AIzaSyDuuyGd8NRWXUZu7XPkK0bs0ap8O7anVAg",
authDomain: "repair-cliente.firebaseapp.com",
projectId: "repair-cliente",
storageBucket: "repair-cliente.appspot.com",
messagingSenderId: "1082010625756",
appId: "1:1082010625756:web:e0c2c70c7a20adc6fe3619",
measurementId: "G-73E5M5RSL8"
};
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);
enableIndexedDbPersistence(db)
.then(()=>{
console.log('base de datos offline habilitada');
})
.catch((err)=>{
if(err.code == 'failed-precondition'){
console.warn('multiples pestañas abiertas');
}else if (err.code == 'unimplemented'){
window.alert('este navegador no es compatible con el modo fuera de linea');
}
});
const auth = getAuth();
(function(){
signInAnonymously(auth)
.then(() => {
console.log('auth...',auth)
})
.catch((error) => {
const errorCode = error.code;
const errorMessage = error.message;
});
onAuthStateChanged(auth, (user) => {
if (user) {
const uid = user.uid;
console.log('usuario creado...'+ uid);
document.getElementById('userId').value = uid;
}
else{
console.log('generando usuario...')}
});
})();

export const userLocationRef = function
(userId, number, location, description, estatus) {
 const docRef = addDoc(collection(db, 'usersLocations'),
{userId, number, location, description, estatus});
  console.log("Documento guardado exitosamente usuario... ", userId);
}
export const onGetLocations = (callback) =>
 onSnapshot(doc(db, "usersLocations", user.uid), (doc) =>{
  console.log("datos actuales", doc.data())
 });
