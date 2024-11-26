import {userLocationRef} from './fb.js'
window.addEventListener('load', ()=>{

var QR_CODE = new QRCode("qrcode", {
  width: 220,
  height: 220,
  colorDark: "#000000",
  colorLight: "#70CAEE",
  correctLevel: QRCode.CorrectLevel.H,
});
const  locationForm = document.getElementById('location-form');
const step2 = document.getElementById('step2');
 locationForm.addEventListener('submit', (e) =>{
    e.preventDefault();
    const userId = locationForm['userId'];
    const number = locationForm['number'];
    const location = locationForm['location'];
    const country = locationForm['country'];
    const description = locationForm['description'];
    var estatus = "espera de respuesta"
    userLocationRef
    (
     userId.value,
     number.value, 
     location.value, 
     country.value, 
     description.value, 
     estatus
     );
    swal('Solicitud exitosa', userId.value);
    locationForm.hidden = true;
    step2.hidden = false;
    QR_CODE.makeCode(userId);
    var btnGuardar = document.getElementById('btnGuardar');
    btnGuardar.addEventListener('click', ()=> {
  var canvas = document.getElementById('qrcode').querySelector('canvas');
  var dataURL = canvas.toDataURL();
  let enlace = document.createElement('a');
  enlace.download =  userId.value;
  enlace.href = dataURL;
  enlace.click();
})


});  
});