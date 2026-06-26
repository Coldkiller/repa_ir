// Firebase setup y funciones
import { initializeApp }
 from "https://www.gstatic.com/firebasejs/9.6.1/firebase-app.js";
import {getAuth, signInAnonymously, onAuthStateChanged}
 from "https://www.gstatic.com/firebasejs/9.6.1/firebase-auth.js";
import {getFirestore, collection, doc, setDoc, getDoc, enableIndexedDbPersistence,onSnapshot}
 from "https://www.gstatic.com/firebasejs/9.6.1/firebase-firestore.js";

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
  .then(() =>{
    return db;
  })
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
    .then(() => {
      return auth;
    })
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
    }
  } catch (error) {
    console.error("Error al verificar datos:", error);
  }
};

// Función para guardar datos en Firestore offline
const saveUserLocation = async (
  userId,
  number,
  location,
  description,
  stat,
) => {
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

// Mostrar el QR y datos dinámicamente
const showQRCode = (userId, data) => {
  // Eliminamos elementos previos del formulario y QR
  const appContainer = document.querySelector("#step1");
  appContainer.replaceChildren(); // Limpia el contenedor principal

  // Crear contenedor del QR
  const qrContainer = document.createElement("div");
  qrContainer.id = "qrcode";

  // Generar el QR Code
  const QR_CODE = new QRCode(qrContainer, {
    width: 250,
    height: 250,
    colorDark: "#000000",
    colorLight: "#ffffff",
    correctLevel: QRCode.CorrectLevel.H,
  });
  QR_CODE.makeCode(userId);
  // Crear lista con los datos
  const dataList = document.createElement("ul");
  dataList.id = "data-list";

  const createListItem = (label, value) => {
    const li = document.createElement("li");
    li.innerHTML = `<strong>${label}:</strong> ${value}`;
    return li;
  };

  dataList.appendChild(createListItem("Clave", data.userId));
  dataList.appendChild(createListItem("Número", data.number));
  dataList.appendChild(createListItem("Dirección", data.location));
  dataList.appendChild(createListItem("Descripción", data.description));
  dataList.appendChild(createListItem("Fecha de Creación", data.timestamp));

  // Botón con el estatus dinámico
  const statButton = document.createElement("button");
  statButton.className = `button-${data.stat} pure-button`;
  statButton.textContent = data.stat;
  const liStat = document.createElement("li");
  const textStat = document.createTextNode("Estatus: ");
  liStat.appendChild(textStat);
  liStat.appendChild(statButton);
  dataList.appendChild(liStat);

  // Agregar contenedores al DOM
  appContainer.appendChild(qrContainer);
  appContainer.appendChild(dataList);

  // Escuchar cambios de estado
  listenToStatusChange(userId, statButton);
  statButton.addEventListener("click", () => {
    QR_CODE.saveCode();
  });
};

// Escucha optimizada de cambios en tiempo real
const listenToStatusChange = (userId, statButton) => {
  const docRef = doc(db, "usersLocations", userId);

  onSnapshot(docRef, (docSnap) => {
    if (docSnap.exists()) {
      const data = docSnap.data();
      if (data.stat) {
        statButton.className =`button-${data.stat} pure-button`;
        statButton.textContent = data.stat;
      }
    } else {
      console.warn("El documento no existe.");
    }
  });
};

// Evento de envío del formulario optimizado
window.addEventListener("load", () => {
  // Geolocalización y geocodificación inversa
const geolocateBtn = document.getElementById("geolocateBtn");
const locationInput = document.getElementById("location");

if (geolocateBtn) {
  geolocateBtn.addEventListener("click", () => {
    if (!navigator.geolocation) {
      Swal.fire("Error", "Tu navegador no soporta geolocalización.", "error");
      return;
    }

    Swal.fire({
      title: "Obteniendo ubicación...",
      text: "Por favor espera mientras obtenemos tu dirección.",
      allowOutsideClick: false,
      didOpen: () => {
        Swal.showLoading();
      }
    });

    navigator.geolocation.getCurrentPosition(
      async (position) => {
        const { latitude, longitude } = position.coords;
        try {
          const address = await getAddressFromCoords(latitude, longitude);
          if (address) {
            locationInput.value = address;
            Swal.fire("Éxito", "Dirección cargada automáticamente.", "success");
          } else {
            throw new Error("No se pudo obtener la dirección");
          }
        } catch (error) {
          console.error(error);
          Swal.fire("Error", "No se pudo convertir las coordenadas a dirección. Intenta escribirla manualmente.", "error");
        }
      },
      (error) => {
        console.error(error);
        let msg = "No se pudo obtener tu ubicación.";
        switch (error.code) {
          case error.PERMISSION_DENIED:
            msg = "Permiso denegado. Activa la ubicación en tu dispositivo.";
            break;
          case error.POSITION_UNAVAILABLE:
            msg = "Información de ubicación no disponible.";
            break;
          case error.TIMEOUT:
            msg = "Tiempo de espera agotado.";
            break;
        }
        Swal.fire("Error", msg, "error");
      }
    );
  });
}

// Función para geocodificación inversa usando Nominatim (OpenStreetMap)
async function getAddressFromCoords(lat, lng) {
  const url = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}&zoom=18&addressdetails=1`;
  try {
    const response = await fetch(url, {
      headers: {
        'Accept-Language': 'es', // Para obtener dirección en español
        'User-Agent': 'RepairClienteApp/1.0' // Identificador requerido por Nominatim
      }
    });
    const data = await response.json();
    if (data && data.display_name) {
      // Extraer solo la parte de calle, número, colonia, ciudad (puedes ajustar)
      return data.display_name;
    }
    return null;
  } catch (error) {
    console.error("Error en geocodificación:", error);
    return null;
  }
}
  const locationForm = document.querySelector("#location-form");
  locationForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    const number = locationForm["number"].value.trim();
    const location = locationForm["location"].value.trim();
    const description = locationForm["description"].value.trim();
    if (!validateForm(number, location, description)) return;

    const userId = locationForm["userId"].value.trim();
    const stat = "espera";
    await saveUserLocation(userId, number, location, description, stat);
  });
});

// Validación de formulario reutilizable
const validateForm = (number, location, description) => {
  const errorMessages = [];

  if (!/^\d{10}$/.test(number)) {
    errorMessages.push(
      "El número de contacto debe tener exactamente 10 dígitos.",
    );
  }
  if (location.length < 5) {
    errorMessages.push("La dirección debe tener al menos 5 caracteres.");
  }
  if (description.length < 10) {
    errorMessages.push(
      "La descripción del problema debe tener mínimo 10 caracteres.",
    );
  }
  if (errorMessages.length > 0) {
    Swal.fire(errorMessages.join("\n"));
    return false;
  }
  return true;
}; 