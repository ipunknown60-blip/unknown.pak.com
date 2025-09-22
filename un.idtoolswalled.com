<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"/>
  <title>IDTools — Multi Upload</title>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.5.13/cropper.min.css"/>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.5.13/cropper.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>
  <style>
    :root{--bg:#0f1724;--card:#0b1220;--accent:#06b6d4;--muted:#94a3b8;}
    body{font-family:Inter,system-ui,Roboto,Arial;background:#071025;color:#e6eef6;margin:0;padding:12px;}
    .wrap{max-width:100%;margin:0 auto;padding:10px;border-radius:12px}
    header{display:flex;align-items:center;gap:10px}
    h1{margin:0;font-size:18px}
    .controls{display:flex;gap:6px;flex-wrap:wrap;margin-top:10px}
    .controls > *{flex:1;padding:10px;border-radius:6px;background:#123;border:1px solid #234;cursor:pointer;color:var(--muted);font-size:14px;text-align:center}
    .viewer{display:flex;flex-direction:column;gap:12px;margin-top:12px}
    .left{width:100%;background:#061420;border-radius:8px;padding:10px;text-align:center}
    canvas,img{max-width:100%;height:auto;border-radius:6px}
    .small{font-size:12px;color:var(--muted)}
    input[type=file]{display:none}
    .btn{background:var(--accent);color:#042024;border:none;padding:10px;border-radius:6px;font-weight:600}
    footer{margin-top:12px;color:var(--muted);font-size:12px;text-align:center}
    .logo{width:36px;height:36px;border-radius:8px;background:linear-gradient(90deg,#06b6d4,#7c3aed);display:flex;align-items:center;justify-content:center;font-weight:700}
    select,input[type=number]{padding:8px;border-radius:6px;border:1px solid #234;background:#123;color:#e6eef6;font-size:14px;width:100%}
    .custom-size{display:none;gap:6px;flex:1}
  </style>
</head>
<body>
  <div class="wrap">
    <header>
      <div class="logo">ID</div>
      <div>
        <h1>IDTools</h1>
        <div class="small">Multi Upload • Crop • Rotate • Enhance • B/W • PDF Export</div>
      </div>
    </header>

    <div class="controls">
      <label class="filebtn">
        Select Files
        <input id="fileInput" type="file" accept=".jpg,.jpeg,.png,image/*" multiple />
      </label>
      <button id="prevBtn">⟨ Prev</button>
      <button id="nextBtn">Next ⟩</button>
      <button id="cropBtn">Crop</button>
      <button id="rotateLeft">⟲ Left</button>
      <button id="rotateRight">↻ Right</button>
      <button id="enhanceBtn">Enhance</button>
      <button id="bwBtn">B/W</button>

      <select id="pageSize">
        <option value="a4" selected>A4</option>
        <option value="letter">Letter</option>
        <option value="legal">Legal</option>
        <option value="custom">Custom</option>
      </select>

      <div class="custom-size" id="customSizeInputs">
        <input type="number" id="customWidth" placeholder="Width (mm)" min="50" max="1000"/>
        <input type="number" id="customHeight" placeholder="Height (mm)" min="50" max="1000"/>
      </div>

      <button id="downloadPdfAll" class="btn">Combine PDF</button>
    </div>

    <div class="viewer">
      <div class="left">
        <img id="sourceImage" style="display:none;max-width:100%"/>
        <canvas id="canvas" style="display:none"></canvas>
      </div>
    </div>

    <footer>© 2025 IDTools</footer>
  </div>

  <script>
    const fileInput = document.getElementById("fileInput");
    const sourceImage = document.getElementById("sourceImage");
    const canvas = document.getElementById("canvas");
    const prevBtn = document.getElementById("prevBtn");
    const nextBtn = document.getElementById("nextBtn");
    const cropBtn = document.getElementById("cropBtn");
    const rotateLeft = document.getElementById("rotateLeft");
    const rotateRight = document.getElementById("rotateRight");
    const enhanceBtn = document.getElementById("enhanceBtn");
    const bwBtn = document.getElementById("bwBtn");
    const downloadPdfAll = document.getElementById("downloadPdfAll");
    const pageSizeSelect = document.getElementById("pageSize");
    const customSizeInputs = document.getElementById("customSizeInputs");
    const customWidth = document.getElementById("customWidth");
    const customHeight = document.getElementById("customHeight");

    let images = [];
    let currentIndex = 0;
    let cropper = null;
    let rotation = 0;

    fileInput.addEventListener("change", (e) => {
      images = [];
      const files = Array.from(e.target.files);
      files.forEach(file => {
        const reader = new FileReader();
        reader.onload = function(evt) {
          images.push(evt.target.result);
          if (images.length === 1) {
            currentIndex = 0;
            rotation = 0;
            showImage();
          }
        };
        reader.readAsDataURL(file);
      });
    });

    function showImage() {
      if (images.length > 0) {
        if (cropper) { cropper.destroy(); cropper = null; }
        sourceImage.style.display = "block";
        sourceImage.src = images[currentIndex];
        rotation = 0;
      }
    }

    prevBtn.addEventListener("click", () => {
      if (images.length > 0) {
        currentIndex = (currentIndex - 1 + images.length) % images.length;
        showImage();
      }
    });

    nextBtn.addEventListener("click", () => {
      if (images.length > 0) {
        currentIndex = (currentIndex + 1) % images.length;
        showImage();
      }
    });

    cropBtn.addEventListener("click", () => {
      if (!cropper) {
        cropper = new Cropper(sourceImage, { viewMode: 1 });
      } else {
        const croppedCanvas = cropper.getCroppedCanvas();
        if (croppedCanvas) {
          images[currentIndex] = croppedCanvas.toDataURL("image/jpeg");
          showImage();
        }
      }
    });

    rotateLeft.addEventListener("click", () => rotateImage(-90));
    rotateRight.addEventListener("click", () => rotateImage(90));

    function rotateImage(deg) {
      if (!images[currentIndex]) return;
      rotation = (rotation + deg) % 360;
      const img = new Image();
      img.src = images[currentIndex];
      img.onload = () => {
        const ctx = canvas.getContext("2d");
        if (rotation % 180 !== 0) {
          canvas.width = img.height;
          canvas.height = img.width;
        } else {
          canvas.width = img.width;
          canvas.height = img.height;
        }
        ctx.clearRect(0,0,canvas.width,canvas.height);
        ctx.save();
        ctx.translate(canvas.width/2, canvas.height/2);
        ctx.rotate(rotation * Math.PI / 180);
        ctx.drawImage(img, -img.width/2, -img.height/2);
        ctx.restore();
        images[currentIndex] = canvas.toDataURL("image/jpeg");
        showImage();
      };
    }

    enhanceBtn.addEventListener("click", () => {
      applyFilter((r,g,b,a)=>[Math.min(255,r*1.1+10),Math.min(255,g*1.1+10),Math.min(255,b*1.1+10),a]);
    });

    bwBtn.addEventListener("click", () => {
      applyFilter((r,g,b,a)=>{let avg=(r+g+b)/3;return [avg,avg,avg,a];});
    });

    function applyFilter(filterFunc) {
      const img = new Image();
      img.src = images[currentIndex];
      img.onload = () => {
        canvas.width = img.width;
        canvas.height = img.height;
        const ctx = canvas.getContext("2d");
        ctx.drawImage(img,0,0);
        let imgData = ctx.getImageData(0,0,canvas.width,canvas.height);
        let data = imgData.data;
        for (let i=0; i<data.length; i+=4){
          [data[i],data[i+1],data[i+2],data[i+3]] = filterFunc(data[i],data[i+1],data[i+2],data[i+3]);
        }
        ctx.putImageData(imgData,0,0);
        images[currentIndex] = canvas.toDataURL("image/jpeg");
        showImage();
      }
    }

    pageSizeSelect.addEventListener("change", () => {
      customSizeInputs.style.display = pageSizeSelect.value === "custom" ? "flex" : "none";
    });

    downloadPdfAll.addEventListener("click", async () => {
      if (images.length === 0) return;
      const { jsPDF } = window.jspdf;

      let format = pageSizeSelect.value;
      if (format === "custom") {
        const w = parseInt(customWidth.value);
        const h = parseInt(customHeight.value);
        if (!w || !h) {
          alert("Please enter valid custom width and height!");
          return;
        }
        format = [w, h];
      }

      const pdf = new jsPDF({ orientation: "p", unit: "mm", format: format });

      for (let i = 0; i < images.length; i++) {
        if (i > 0) pdf.addPage();
        let img = new Image();
        img.src = images[i];
        await new Promise(resolve => {
          img.onload = () => {
            const pageWidth = pdf.internal.pageSize.getWidth();
            const pageHeight = pdf.internal.pageSize.getHeight();
            let imgWidth = pageWidth;
            let imgHeight = (img.height * imgWidth) / img.width;

            if (imgHeight > pageHeight) {
              imgHeight = pageHeight;
              imgWidth = (img.width * imgHeight) / img.height;
            }

            const x = (pageWidth - imgWidth) / 2;
            const y = (pageHeight - imgHeight) / 2;

            pdf.addImage(img, "JPEG", x, y, imgWidth, imgHeight);
            resolve();
          };
        });
      }
      pdf.save("combined.pdf");
    });
  </script>
</body>
</html>
