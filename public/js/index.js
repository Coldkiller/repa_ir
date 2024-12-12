import { userLocationRef } from "./fb.js";
window.addEventListener("load", () => {
  var QR_CODE = new QRCode("qrcode", {
    width: 220,
    height: 220,
    colorDark: "#000000",
    colorLight: "#70CAEE",
    correctLevel: QRCode.CorrectLevel.H,
  });
  const locationForm = document.getElementById("location-form");
  const step2 = document.getElementById("step2");

  // Función para validar el formulario
  const validateForm = () => {
    const number = locationForm['number'].value.trim();
    const location = locationForm['location'].value.trim();
    const description = locationForm['description'].value.trim();

    let isValid = true;
    let errorMessages = [];

    // Validar número
    if (!/^\d{10}$/.test(number)) {
      errorMessages.push("El número de contacto debe tener exactamente 10 dígitos.");
      isValid = false;
    }

    // Validar dirección
    if (location.length < 5) {
      errorMessages.push("La dirección debe tener al menos 5 caracteres.");
      isValid = false;
    }

    // Validar descripción
    if (description.length < 10) {
      errorMessages.push("La descripción del problema debe ser más detallada (mínimo 10 caracteres).");
      isValid = false;
    }

    // Mostrar mensajes de error
    if (!isValid) {
      swal.fire(errorMessages.join("\n"));
    }

    return isValid;
  };

  // Evento de envío del formulario
  locationForm.addEventListener('submit', (e) => {
    e.preventDefault(); // Evitar comportamiento predeterminado

    // Validar antes de proceder
    if (!validateForm()) {
      return; // Detener si no pasa la validación
    }







  locationForm.addEventListener("submit", (e) => {
    e.preventDefault();
        // Validar antes de proceder
    if (!validateForm()) {
      return; // Detener si no pasa la validación
    }

   const userId = locationForm['userId'].value.trim();
    const number = locationForm['number'].value.trim();
    const location = locationForm['location'].value.trim();
    const description = locationForm['description'].value.trim();
    const estatus = "espera de respuesta";
    userLocationRef(
      userId,
      number,
      location,
      description,
      estatus,
    );
    swal.fire("Solicitud exitosa", userId.value);
    locationForm.hidden = true;
    step2.hidden = false;
       setTimeout(() => {
        QR_CODE.makeCode(userId);
      }, 500);
    var btnGuardar = document.getElementById("btnGuardar");
    btnGuardar.addEventListener("click", () => {
      var canvas = document.getElementById("qrcode").querySelector("canvas");
      var dataURL = canvas.toDataURL();
      let enlace = document.createElement("a");
      enlace.download = userId.value;
      enlace.href = dataURL;
      enlace.click();
    });
  });
});
});