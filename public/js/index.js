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
  onSnapshot,
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
    switch (err.code) {
      case "failed-precondition":
        console.warn("Múltiples pestañas abiertas");
        break;
      case "unimplemented":
        Swal.fire("Este navegador no es compatible con el modo fuera de línea");
        break;
      default:
        console.error("Error al habilitar la persistencia offline:", err);
    }
  });

// Iniciar sesión anónima
const initializeAnonymousUser = () => {
  signInAnonymously(auth)
    .then(() => console.log("Autenticado anónimamente"))
    .catch((error) => console.error("Error en la autenticación:", error));
};

// Evento de cambio de estado del usuario
onAuthStateChanged(auth, async (user) => {
  if (user) {
    const uid = user.uid;
    console.log("Usuario anónimo creado:", uid);
    document.querySelector("#userId").value = uid;
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
const saveUserLocation = async (userId, number, location, description, stat) => {
  try {
    const docRef = doc(db, "usersLocations", userId);
    const timestamp = new Date().toISOString();
    const data = { userId, number, location, description, stat, timestamp };
    await setDoc(docRef, data);

    Swal.fire({
      position: "top-end",
      icon: "success",
      title: "Solicitud exitosa",
      showConfirmButton: false,
      timer: 2000,
    });

    showQRCode(userId, data);
  } catch (error) {
    console.error("Error al guardar datos:", error);
    Swal.fire("Error al guardar los datos");
  }
};

// Función para mostrar el QR, ocultar el formulario e insertar una lista con los datos
const showQRCode = (userId, data) => {
  const step1 = document.querySelector("#step1");
  const step2 = document.querySelector("#step2");
  const QR_CODE = new QRCode("qrcode", {
    width: 220,
    height: 220,
    colorDark: "#000000",
    colorLight: "#70CAEE",
    correctLevel: QRCode.CorrectLevel.H,
  });

  // Ocultar el formulario y mostrar el QR
  step1.hidden = true;
  step2.hidden = false;
  setTimeout(() => QR_CODE.makeCode(userId), 10);

  // Insertar lista con los datos al lado del QR sin usar innerHTML
  const dataList = document.querySelector("#data-list");
  dataList.replaceChildren(); // Limpia contenido previo

  const ul = document.createElement("ul");

  const createListItem = (label, value) => {
    const li = document.createElement("li");
    li.innerHTML = `<strong>${label}:</strong> ${value}`;
    return li;
  };

  ul.appendChild(createListItem("Id", data.userId));
  ul.appendChild(createListItem("Número", data.number));
  ul.appendChild(createListItem("Dirección", data.location));
  ul.appendChild(createListItem("Descripción", data.description));
  ul.appendChild(createListItem("Fecha de Creación", data.timestamp));

  const liStat = document.createElement("li");
  liStat.innerHTML = `<strong>Estatus:</strong> <button class="button-primary pure-button">${data.stat}</button>`;
  ul.appendChild(liStat);

  dataList.appendChild(ul);

  // Iniciar escucha de cambios en el stat
  listenToStatusChange(userId);
};

// Lógica del formulario y QR
window.addEventListener("load", () => {
  const locationForm = document.querySelector("#location-form");
  const btnGuardar = document.querySelector("#btnGuardar");

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
      Swal.fire(errorMessages.join("\n"));
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
    const stat = "primary";

    await saveUserLocation(userId, number, location, description, stat);
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
});

// Función para escuchar cambios en tiempo real
const listenToStatusChange = (userId) => {
  const docRef = doc(db, "usersLocations", userId);
  let lastStat = null;

  onSnapshot(docRef, (docSnap) => {
    if (docSnap.exists()) {
      const data = docSnap.data();

      // Verificar si el stat ha cambiado desde el último valor
      if (data.stat && data.stat !== lastStat) {
        lastStat = data.stat;
        const statElement = document.querySelector("#data-list li:nth-child(6)");
        if (statElement) {
          statElement.innerHTML = `<strong>Estatus:</strong> <button class="button-${data.stat} pure-button">${data.stat}</button>`;
        }
      }
    } else {
      console.warn("El documento no existe.");
    }
  });
};
