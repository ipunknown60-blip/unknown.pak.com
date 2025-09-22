<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"/>
<title>Unknown IDTools — Final</title>

<!-- Styles (Cropper CSS via CDN) -->
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.5.13/cropper.min.css"/>
<style>
  :root { --bg:#071025; --card:#061420; --accent:#06b6d4; --muted:#94a3b8; }
  html,body{height:100%;margin:0;font-family:Inter,system-ui,Roboto,Arial;background:linear-gradient(180deg,#071025,#06162a);color:#e6eef6}
  .app{max-width:980px;margin:14px auto;padding:14px;border-radius:12px;background:rgba(255,255,255,0.02);box-shadow:0 8px 30px rgba(2,6,23,0.6)}
  header{display:flex;gap:12px;align-items:center}
  .logo{width:46px;height:46px;border-radius:10px;background:linear-gradient(90deg,#06b6d4,#7c3aed);display:flex;align-items:center;justify-content:center;font-weight:700}
  h1{margin:0;font-size:18px}
  .desc{color:var(--muted);font-size:13px}
  .controls{display:flex;gap:8px;flex-wrap:wrap;margin-top:12px}
  .filebtn{background:rgba(255,255,255,0.02);padding:10px 12px;border-radius:8px;border:1px solid rgba(255,255,255,0.03);cursor:pointer;color:var(--muted)}
  button.tool{background:rgba(255,255,255,0.03);color:var(--muted);border:1px solid rgba(255,255,255,0.02);padding:10px 12px;border-radius:8px;cursor:pointer}
  button.primary{background:var(--accent);color:#042024;border:none}
  .viewer{display:flex;gap:12px;margin-top:12px;align-items:flex-start}
  .left{flex:1;min-height:360px;background:var(--card);border-radius:10px;padding:10px;display:flex;flex-direction:column;align-items:center;justify-content:center}
  .right{width:320px;background:var(--card);border-radius:10px;padding:10px;box-sizing:border-box}
  img#sourceImage, canvas#workCanvas{max-width:100%;max-height:640px;border-radius:8px;display:block}
  .small{font-size:13px;color:var(--muted)}
  .slim{font-size:12px;color:var(--muted)}
  .gallery{display:flex;gap:8px;flex-wrap:wrap;margin-top:8px}
  .thumb{width:64px;height:40px;border-radius:6px;background:#08121a;display:flex;align-items:center;justify-content:center;overflow:hidden;cursor:pointer;border:2px solid transparent}
  .thumb.active{border-color:var(--accent)}
  .right .section{margin-bottom:10px}
  footer{margin-top:14px;color:var(--muted);font-size:13px;text-align:center}
  @media (max-width:820px){
    .viewer{flex-direction:column}
    .right{width:100%}
  }
</style>
</head>
<body>
  <div class="app" id="app">
    <header>
      <div class="logo">ID</div>
      <div>
        <h1>Unknown IDTools — Final</h1>
        <div class="desc">Multi Upload • Reliable Crop • Rotate • Auto-Enhance • B/W • OCR • Export (PNG/JPG/PDF)</div>
      </div>
    </header>

    <div class="controls">
      <label class="filebtn">
        Select files
        <input id="fileInput" type="file" accept=".jpg,.jpeg,.png,.pdf,image/*" multiple style="display:none"/>
      </label>

      <button class="tool" id="prevBtn" title="Previous file">⟸ Prev</button>
      <button class="tool" id="nextBtn" title="Next file">Next ⟹</button>
      <button class="tool" id="cropBtn" title="Crop selection">Crop</button>
      <button class="tool" id="rotateLeft" title="Rotate -90">⟲</button>
      <button class="tool" id="rotateRight" title="Rotate +90">↻</button>
      <button class="tool" id="autoEnhance" title="Auto enhance image">Auto Enhance</button>
      <button class="tool" id="bwBtn" title="Black & White">B/W</button>
      <button class="tool" id="contrastBtn" title="Contrast">Contrast+</button>
      <button class="tool" id="ocrBtn" title="Read text (OCR)">OCR</button>

      <div style="flex:1"></div>

      <button class="tool primary" id="downloadPng">Download PNG</button>
      <button class="tool primary" id="downloadJpg">Download JPG</button>
      <button class="tool primary" id="downloadPdf">Download PDF</button>
    </div>

    <div class="viewer">
      <div class="left">
        <div id="placeholder" class="small">No file selected — upload images or PDFs (multiple)</div>

        <!-- image shown when editing -->
        <img id="sourceImage" style="display:none" crossorigin="anonymous" />

        <!-- canvas view (after crop/apply filters) -->
        <canvas id="workCanvas" style="display:none"></canvas>

        <div class="gallery" id="gallery"></div>
      </div>

      <div class="right">
        <div class="section slim"><strong class="small">Preview controls</strong></div>

        <div class="section">
          <div class="small">Zoom / Rotate (Crop Mode)</div>
          <input id="zoom" type="range" min="0.2" max="3" step="0.01" value="1" style="width:100%"/>
        </div>

        <div class="section">
          <div class="small">Brightness</div>
          <input id="brightness" type="range" min="0.5" max="2" step="0.01" value="1" style="width:100%"/>
          <div class="small">Contrast</div>
          <input id="contrast" type="range" min="0.5" max="2" step="0.01" value="1" style="width:100%"/>
        </div>

        <div class="section">
          <div class="small">OCR Output</div>
          <pre id="ocrOutput" style="white-space:pre-wrap;background:#071827;padding:8px;border-radius:6px;height:160px;overflow:auto"></pre>
        </div>

        <div class="section slim small">Domain: <strong>www.unknown.idtools.com</strong></div>
      </div>
    </div>

    <footer class="slim">All processing runs locally in your browser. Recommended: Google Chrome (mobile & desktop).</footer>
  </div>

  <!-- Libraries -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.5.13/cropper.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/FileSaver.js/2.0.5/FileSaver.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/2.14.305/pdf.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/tesseract.js@4.1.1/dist/tesseract.min.js"></script>

<script>
/*
  Final IDTools — single-file app script
  Features:
    - multiple files upload & gallery
    - cropper per image (destroy/re-init safely)
    - PDF first page render via pdf.js to canvas then converted to image for cropping
    - auto-enhance: brightness + contrast + sharpen (unsharp kernel)
    - B/W, contrast filter
    - OCR via Tesseract.js (english by default)
    - download PNG/JPG/PDF using FileSaver + jsPDF
    - responsive + mobile-friendly
*/

const fileInput = document.getElementById('fileInput');
const sourceImage = document.getElementById('sourceImage');
const placeholder = document.getElementById('placeholder');
const workCanvas = document.getElementById('workCanvas');
const ctx = workCanvas.getContext('2d');
const gallery = document.getElementById('gallery');
const ocrOutput = document.getElementById('ocrOutput');

let filesList = [];        // {file, url, type, name}
let activeIndex = -1;
let cropper = null;
let currentUrl = null;

// Utility helpers
const clamp = v => Math.max(0, Math.min(255, Math.round(v)));
function clearCropper(){ if(cropper){ try{ cropper.destroy(); }catch(e){} cropper=null; } }
function showPlaceholder(){ placeholder.style.display='block'; sourceImage.style.display='none'; workCanvas.style.display='none'; }
function showImageElement(){ sourceImage.style.display='block'; workCanvas.style.display='none'; placeholder.style.display='none'; }
function showCanvasElement(){ sourceImage.style.display='none'; workCanvas.style.display='block'; placeholder.style.display='none'; }

function addThumb(dataUrl, index){
  const div = document.createElement('div');
  div.className = 'thumb';
  const img = document.createElement('img');
  img.src = dataUrl;
  img.style.width = '100%';
  img.style.height = '100%';
  img.style.objectFit = 'cover';
  div.appendChild(img);
  div.onclick = ()=> setActive(index);
  gallery.appendChild(div);
  return div;
}
function refreshGalleryActive(){
  Array.from(gallery.children).forEach((ch, i)=> ch.classList.toggle('active', i===activeIndex));
}

// Load file(s)
fileInput.addEventListener('change', async (e)=>{
  const files = Array.from(e.target.files || []);
  if(!files.length) return;
  // Clear previous
  filesList = [];
  gallery.innerHTML = '';
  activeIndex = -1;
  clearCropper();
  showPlaceholder();

  for(const f of files){
    const type = f.type;
    const name = f.name;
    if(type === 'application/pdf' || name.toLowerCase().endsWith('.pdf')){
      // render first page to image dataURL
      try{
        const arrayBuffer = await f.arrayBuffer();
        const pdf = await pdfjsLib.getDocument({data:new Uint8Array(arrayBuffer)}).promise;
        const page = await pdf.getPage(1);
        const viewport = page.getViewport({scale:1.4});
        const tmpCanvas = document.createElement('canvas');
        tmpCanvas.width = Math.round(viewport.width);
        tmpCanvas.height = Math.round(viewport.height);
        const tmpCtx = tmpCanvas.getContext('2d');
        await page.render({canvasContext:tmpCtx, viewport}).promise;
        const url = tmpCanvas.toDataURL('image/png');
        filesList.push({file:f, url, type:'image/png', name});
        addThumb(url, filesList.length-1);
      }catch(err){
        console.error('PDF render error', err);
        alert('Error rendering PDF: '+name);
      }
    } else if(type.startsWith('image/') || /\.(jpg|jpeg|png|gif|webp|bmp)$/i.test(name)){
      const url = URL.createObjectURL(f);
      filesList.push({file:f, url, type, name});
      addThumb(url, filesList.length-1);
    } else {
      // unsupported
      alert('Unsupported file type: '+name);
    }
  }

  if(filesList.length){
    setActive(0);
  } else {
    showPlaceholder();
  }
});

// Set active file by index
async function setActive(index){
  if(index<0 || index>=filesList.length) return;
  activeIndex = index;
  refreshGalleryActive();
  const item = filesList[index];
  // ensure previous cropper destroyed
  clearCropper();
  // revoke previous url when it's an object URL created by us? We'll keep for session; revoke when clearing all.
  // For image: set src to image element
  sourceImage.style.maxHeight = '640px';
  sourceImage.onload = ()=> {
    // init cropper after image has natural size
    initCropperSafe();
    showImageElement();
  };
  sourceImage.onerror = ()=> {
    alert('Cannot load image.');
  };
  sourceImage.src = item.url;
}

// Initialize cropper safely
function initCropperSafe(){
  clearCropper();
  cropper = new Cropper(sourceImage, {
    viewMode: 1,
    background: false,
    autoCrop: true,
    movable: true,
    zoomable: true,
    rotatable: true,
    scalable: true,
    responsive: true,
    restore: true,
    modal: true,
    guides: true,
    highlight: true,
    cropBoxMovable: true,
    cropBoxResizable: true,
    ready(){
      // sync zoom slider to cropper.zoomTo when used
    }
  });
}

// Crop action
document.getElementById('cropBtn').addEventListener('click', ()=>{
  if(!cropper){ alert('No image loaded or cropper not ready.'); return; }
  try{
    const croppedCanvas = cropper.getCroppedCanvas({maxWidth:3000, maxHeight:3000, imageSmoothingQuality:'high'});
    applyCanvas(croppedCanvas);
    // replace current file url with new data URL so next edits operate on cropped image
    const dataUrl = croppedCanvas.toDataURL('image/png');
    filesList[activeIndex].url = dataUrl;
    // destroy old cropper and show canvas
    clearCropper();
    showCanvasElement();
    refreshGalleryActive();
    // update gallery thumbnail
    gallery.children[activeIndex].querySelector('img').src = dataUrl;
  }catch(err){
    console.error('Crop error', err);
    alert('Crop failed: '+err.message);
  }
});

// draw canvas (accepts canvas or image)
function applyCanvas(source){
  if(source instanceof HTMLCanvasElement){
    workCanvas.width = source.width;
    workCanvas.height = source.height;
    ctx.clearRect(0,0,workCanvas.width,workCanvas.height);
    ctx.drawImage(source,0,0);
    showCanvasElement();
  } else {
    // image element
    workCanvas.width = source.naturalWidth || source.width;
    workCanvas.height = source.naturalHeight || source.height;
    ctx.clearRect(0,0,workCanvas.width,workCanvas.height);
    ctx.drawImage(source,0,0,workCanvas.width, workCanvas.height);
    showCanvasElement();
  }
}

// Rotate
document.getElementById('rotateLeft').addEventListener('click', ()=> rotateActive(-90));
document.getElementById('rotateRight').addEventListener('click', ()=> rotateActive(90));
function rotateActive(deg){
  if(cropper){
    cropper.rotate(deg);
    return;
  }
  if(workCanvas.style.display==='none'){
    // no canvas — draw image to canvas first
    const img = new Image();
    img.onload = ()=>{
      // rotate canvas
      const temp = document.createElement('canvas');
      const tctx = temp.getContext('2d');
      const w = img.naturalWidth, h = img.naturalHeight;
      temp.width = h; temp.height = w;
      tctx.translate(temp.width/2, temp.height/2);
      tctx.rotate(deg * Math.PI/180);
      tctx.drawImage(img, -w/2, -h/2);
      applyCanvas(temp);
      // update filesList url to resulting data (replace)
      const dataUrl = temp.toDataURL('image/png');
      filesList[activeIndex].url = dataUrl;
      if(gallery.children[activeIndex]) gallery.children[activeIndex].querySelector('img').src = dataUrl;
    };
    img.src = filesList[activeIndex].url;
  } else {
    // rotate existing canvas content
    const temp = document.createElement('canvas');
    const tctx = temp.getContext('2d');
    temp.width = workCanvas.height; temp.height = workCanvas.width;
    tctx.translate(temp.width/2, temp.height/2);
    tctx.rotate(deg * Math.PI/180);
    tctx.drawImage(workCanvas, -workCanvas.width/2, -workCanvas.height/2);
    applyCanvas(temp);
    const dataUrl = temp.toDataURL('image/png');
    filesList[activeIndex].url = dataUrl;
    if(gallery.children[activeIndex]) gallery.children[activeIndex].querySelector('img').src = dataUrl;
  }
}

// Auto enhance: brightness + contrast + sharpen (convolution)
document.getElementById('autoEnhance').addEventListener('click', ()=>{
  if(workCanvas.style.display==='none'){
    // draw current image into canvas first
    const img = new Image();
    img.crossOrigin = "anonymous";
    img.onload = ()=>{
      workCanvas.width = img.naturalWidth; workCanvas.height = img.naturalHeight;
      ctx.drawImage(img,0,0);
      enhanceAndSharpen();
    };
    img.src = filesList[activeIndex].url;
  } else {
    enhanceAndSharpen();
  }
});

function enhanceAndSharpen(){
  try{
    // basic brightness & contrast first
    const brightness = parseFloat(document.getElementById('brightness').value) || 1.05;
    const contrast = parseFloat(document.getElementById('contrast').value) || 1.15;
    let id = ctx.getImageData(0,0,workCanvas.width, workCanvas.height);
    const d = id.data;
    // apply brightness/contrast
    for(let i=0;i<d.length;i+=4){
      for(let c=0;c<3;c++){
        // contrast: (value-128)*contrast +128 then brightness multiply
        let v = (d[i+c] - 128) * contrast + 128;
        v = v * brightness;
        d[i+c] = clamp(v);
      }
    }
    ctx.putImageData(id,0,0);

    // then apply simple sharpen kernel (3x3)
    const sharpenKernel = [ -1, -1, -1, -1, 9, -1, -1, -1, -1 ];
    convolveCanvas(ctx, workCanvas.width, workCanvas.height, sharpenKernel, 1, 0);
    // update filesList URL and gallery thumb
    const dataUrl = workCanvas.toDataURL('image/png');
    filesList[activeIndex].url = dataUrl;
    if(gallery.children[activeIndex]) gallery.children[activeIndex].querySelector('img').src = dataUrl;
    // ensure cropper uses new src if needed
    clearCropper();
    sourceImage.src = dataUrl;
    showCanvasElement();
  }catch(err){
    console.error('Enhance error', err);
    alert('Auto Enhance failed: '+err.message);
  }
}

// convolution helper
function convolveCanvas(ctx, w, h, kernel, factor=1, bias=0){
  const src = ctx.getImageData(0,0,w,h);
  const dst = ctx.createImageData(w,h);
  const d = dst.data, s = src.data;
  const kw = Math.round(Math.sqrt(kernel.length));
  const half = Math.floor(kw/2);
  for(let y=0;y<h;y++){
    for(let x=0;x<w;x++){
      let r=0,g=0,b=0;
      for(let ky=0; ky<kw; ky++){
        for(let kx=0; kx<kw; kx++){
          const px = x + kx - half;
          const py = y + ky - half;
          if(px>=0 && px<w && py>=0 && py<h){
            const i = (py*w + px)*4;
            const kval = kernel[ky*kw + kx];
            r += s[i]*kval;
            g += s[i+1]*kval;
            b += s[i+2]*kval;
          }
        }
      }
      const idx = (y*w + x)*4;
      d[idx] = clamp(factor * r + bias);
      d[idx+1] = clamp(factor * g + bias);
      d[idx+2] = clamp(factor * b + bias);
      d[idx+3] = s[idx+3]; // alpha
    }
  }
  ctx.putImageData(dst,0,0);
}

// B/W
document.getElementById('bwBtn').addEventListener('click', ()=>{
  if(workCanvas.style.display==='none'){
    // draw image to canvas first then convert
    const img = new Image();
    img.onload = ()=>{
      workCanvas.width = img.naturalWidth; workCanvas.height = img.naturalHeight;
      ctx.drawImage(img,0,0);
      applyBW();
    };
    img.src = filesList[activeIndex].url;
  } else {
    applyBW();
  }
});

function applyBW(){
  const id = ctx.getImageData(0,0,workCanvas.width, workCanvas.height);
  const d = id.data;
  for(let i=0;i<d.length;i+=4){
    const v = 0.299*d[i] + 0.587*d[i+1] + 0.114*d[i+2];
    // use adaptive threshold? simple fixed threshold for now
    const t = 140;
    const val = (v>t)?255:0;
    d[i]=d[i+1]=d[i+2]=val;
  }
  ctx.putImageData(id,0,0);
  const dataUrl = workCanvas.toDataURL('image/png');
  filesList[activeIndex].url = dataUrl;
  if(gallery.children[activeIndex]) gallery.children[activeIndex].querySelector('img').src = dataUrl;
}

// Contrast quick
document.getElementById('contrastBtn').addEventListener('click', ()=>{
  if(workCanvas.style.display==='none'){
    const img = new Image();
    img.onload = ()=>{
      workCanvas.width = img.naturalWidth; workCanvas.height = img.naturalHeight;
      ctx.drawImage(img,0,0);
      applyContrast(1.25);
    };
    img.src = filesList[activeIndex].url;
  } else applyContrast(1.25);
});
function applyContrast(factor){
  const id = ctx.getImageData(0,0,workCanvas.width, workCanvas.height);
  const d = id.data;
  for(let i=0;i<d.length;i+=4){
    for(let c=0;c<3;c++){
      d[i+c] = clamp((d[i+c]-128)*factor + 128);
    }
  }
  ctx.putImageData(id,0,0);
  const dataUrl = workCanvas.toDataURL('image/png');
  filesList[activeIndex].url = dataUrl;
  if(gallery.children[activeIndex]) gallery.children[activeIndex].querySelector('img').src = dataUrl;
}

// OCR
document.getElementById('ocrBtn').addEventListener('click', async ()=>{
  try{
    ocrOutput.textContent = 'Reading... (this may take a few seconds)';
    // ensure canvas has image
    if(workCanvas.style.display==='none'){
      const img = new Image();
      img.crossOrigin = "anonymous";
      img.onload = ()=> {
        workCanvas.width = img.naturalWidth; workCanvas.height = img.naturalHeight;
        ctx.drawImage(img,0,0);
        runOCR();
      };
      img.src = filesList[activeIndex].url;
    } else {
      runOCR();
    }
  }catch(err){
    console.error(err); ocrOutput.textContent = 'OCR error: '+err.message;
  }
});

async function runOCR(){
  try{
    const blob = await new Promise(res=> workCanvas.toBlob(res,'image/png'));
    const { createWorker } = Tesseract;
    const worker = createWorker({
      logger: m => { /* optionally show progress: console.log(m) */ }
    });
    await worker.load();
    await worker.loadLanguage('eng');
    await worker.initialize('eng');
    const { data: { text } } = await worker.recognize(blob);
    await worker.terminate();
    ocrOutput.textContent = text || 'No text found';
  }catch(err){
    console.error('OCR fail', err);
    ocrOutput.textContent = 'OCR failed: '+err.message;
  }
}

// Download functions
function downloadCanvasAs(type, filename){
  if(workCanvas.style.display==='none'){
    // draw current image to canvas then save
    const img = new Image();
    img.onload = ()=>{
      workCanvas.width = img.naturalWidth; workCanvas.height = img.naturalHeight;
      ctx.drawImage(img,0,0);
      saveCanvas(type, filename);
    };
    img.src = filesList[activeIndex].url;
  } else saveCanvas(type, filename);
}

function saveCanvas(type, filename){
  workCanvas.toBlob(blob=>{
    if(type==='image/png' || type==='image/jpeg'){
      saveAs(blob, filename);
    } else if(type==='pdf'){
      const { jsPDF } = window.jspdf;
      const pdf = new jsPDF({orientation: workCanvas.width>workCanvas.height ? 'l':'p', unit:'px', format:[workCanvas.width, workCanvas.height]});
      const dataUrl = workCanvas.toDataURL('image/png');
      pdf.addImage(dataUrl, 'PNG', 0, 0, workCanvas.width, workCanvas.height);
      pdf.save(filename);
    }
  }, type, 0.95);
}

document.getElementById('downloadPng').addEventListener('click', ()=> downloadCanvasAs('image/png','idcard.png'));
document.getElementById('downloadJpg').addEventListener('click', ()=> downloadCanvasAs('image/jpeg','idcard.jpg'));
document.getElementById('downloadPdf').addEventListener('click', ()=> downloadCanvasAs('pdf','idcard.pdf'));

// Next / Prev
document.getElementById('nextBtn').addEventListener('click', ()=> {
  if(filesList.length===0) return;
  setActive((activeIndex+1) % filesList.length);
});
document.getElementById('prevBtn').addEventListener('click', ()=> {
  if(filesList.length===0) return;
  setActive((activeIndex-1 + filesList.length) % filesList.length);
});

// Zoom slider applies to cropper zoom
document.getElementById('zoom').addEventListener('input', (e)=>{
  if(cropper){
    const v = parseFloat(e.target.value);
    try{ cropper.zoomTo(v); } catch(e){ /* ignore */ }
  }
});

// Brightness/contrast sliders preview
document.getElementById('brightness').addEventListener('input', previewBC);
document.getElementById('contrast').addEventListener('input', previewBC);
function previewBC(){
  if(!filesList[activeIndex]) return;
  // apply non-destructive preview by drawing original image and applying bc in canvas
  const img = new Image();
  img.onload = ()=>{
    workCanvas.width = img.naturalWidth; workCanvas.height = img.naturalHeight;
    ctx.drawImage(img,0,0);
    const id = ctx.getImageData(0,0,workCanvas.width,workCanvas.height);
    const d = id.data;
    const b = parseFloat(document.getElementById('brightness').value);
    const c = parseFloat(document.getElementById('contrast').value);
    for(let i=0;i<d.length;i+=4){
      for(let ch=0; ch<3; ch++){
        let v = (d[i+ch]-128)*c + 128;
        v = v * b;
        d[i+ch] = clamp(v);
      }
    }
    ctx.putImageData(id,0,0);
    showCanvasElement();
  };
  img.src = filesList[activeIndex].url;
}

// when user clicks thumb we setActive via addThumb onclick above

// initial state
showPlaceholder();

</script>
</body>
</html>
