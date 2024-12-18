// Firebase setup y funciones
import { initializeApp } from "https://www.gstatic.com/firebasejs/9.6.1/firebase-app.js";
import {
  getAuth,
  signInAnonymously,
  onAuthStateChanged,
} from "https://www.gstatic.com/firebasejs/9.6.1/firebase-auth.js";
import {
  getFirestore,
  collection,
  doc,
  setDoc,
  getDoc,
  enableIndexedDbPersistence,
} from "https://www.gstatic.com/firebasejs/9.6.1/firebase-firestore.js";

// Configuración de Firebase
const firebaseConfig = {
  apiKey: "AIzaSyDuuyGd8NRWXUZu7XPkK0bs0ap8O7anVAg",
  authDomain: "repair-cliente.firebaseapp.com",
  projectId: "repair-cliente",
  storageBucket: "repair-cliente.appspot.com",
  messagingSenderId: "1082010625756",
  appId: "1:1082010625756:web:e0c2c70c7a20adc6fe3619",
  measurementId: "G-73E5M5RSL8",
};

// Inicialización de Firebase
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);
const auth = getAuth();

// Habilitar la persistencia offline
enableIndexedDbPersistence(db)
  .then(() => console.log("Base de datos offline habilitada"))
  .catch((err) => {
    if (err.code === "failed-precondition") {
      console.warn("Múltiples pestañas abiertas");
    } else if (err.code === "unimplemented") {
      swal.fire("Este navegador no es compatible con el modo fuera de línea");
    }
  });

// Iniciar sesión anónima
function initializeAnonymousUser() {
  signInAnonymously(auth)
    .then(() => console.log("Autenticado anónimamente"))
    .catch((error) => console.error("Error en la autenticación:", error));
}

// Evento de cambio de estado del usuario
onAuthStateChanged(auth, async (user) => {
  if (user) {
    const uid = user.uid;
    console.log("Usuario anónimo creado:", uid);
    document.getElementById("userId").value = uid;
    await checkExistingData(uid);
  } else {
    console.log("Generando usuario...");
    initializeAnonymousUser();
  }
});

// Función para verificar si existen datos guardados offline
const checkExistingData = async (userId) => {
  const docRef = doc(db, "usersLocations", userId);
  try {
    const docSnap = await getDoc(docRef);
    if (docSnap.exists()) {
      showQRCode(userId, docSnap.data());
    } else {
      console.log("No se encontraron datos previos.");
    }
  } catch (error) {
    console.error("Error al verificar datos:", error);
  }
};

// Función para guardar datos en Firestore offline
const saveUserLocation = async (userId, number, location, description, estatus) => {
  try {
    const docRef = doc(db, "usersLocations", userId);
    const data = { userId, number, location, description, estatus };
    await setDoc(docRef, data);
    swal.fire("Solicitud exitosa", `Datos guardados para el usuario ${userId}`);
    showQRCode(userId, data);
  } catch (error) {
    console.error("Error al guardar datos:", error);
    swal.fire("Error al guardar los datos");
  }
};

// Función para mostrar el QR, ocultar el formulario e insertar una lista con los datos
const showQRCode = (userId, data) => {
  const locationForm = document.getElementById("location-form");
  const step2 = document.getElementById("step2");
  const QR_CODE = new QRCode("qrcode", {
    width: 220,
    height: 220,
    colorDark: "#000000",
    colorLight: "#70CAEE",
    correctLevel: QRCode.CorrectLevel.H,
  });

  // Ocultar el formulario y mostrar el QR
  locationForm.hidden = true;
  step2.hidden = false;

  setTimeout(() => QR_CODE.makeCode(userId), 10);

  // Insertar lista con los datos al lado del QR
  const dataList = document.getElementById("data-list");
  dataList.innerHTML = `
    <ul>
      <li><strong>Id:</strong> ${data.userId}</li>
      <li><strong>Número:</strong> ${data.number}</li>
      <li><strong>Dirección:</strong> ${data.location}</li>
      <li><strong>Descripción:</strong> ${data.description}</li>
      <li><strong>Estatus:</strong> ${data.estatus}</li>
    </ul>
  `;
};

// Lógica del formulario y QR
window.addEventListener("load", () => {
  const locationForm = document.getElementById("location-form");
  const btnGuardar = document.getElementById("btnGuardar");

  // Función para validar el formulario
  const validateForm = () => {
    const number = locationForm["number"].value.trim();
    const location = locationForm["location"].value.trim();
    const description = locationForm["description"].value.trim();
    const errorMessages = [];

    if (!/^\d{10}$/.test(number)) {
      errorMessages.push("El número de contacto debe tener exactamente 10 dígitos.");
    }
    if (location.length < 5) {
      errorMessages.push("La dirección debe tener al menos 5 caracteres.");
    }
    if (description.length < 10) {
      errorMessages.push("La descripción del problema debe tener mínimo 10 caracteres.");
    }

    if (errorMessages.length > 0) {
      swal.fire(errorMessages.join("\n"));
      return false;
    }

    return true;
  };

  // Evento de envío del formulario
  locationForm.addEventListener("submit", async (e) => {
    e.preventDefault();

    if (!validateForm()) return;

    const userId = locationForm["userId"].value.trim();
    const number = locationForm["number"].value.trim();
    const location = locationForm["location"].value.trim();
    const description = locationForm["description"].value.trim();
    const estatus = "espera de respuesta";

    await saveUserLocation(userId, number, location, description, estatus);
  });

  // Evento para descargar el código QR
  btnGuardar.addEventListener("click", () => {
    const canvas = document.querySelector("#qrcode canvas");
    const dataURL = canvas.toDataURL();
    const enlace = document.createElement("a");
    enlace.download = `${locationForm["userId"].value}.png`;
    enlace.href = dataURL;
    enlace.click();
  });

  initializeAnonymousUser();
});
