<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Unknown IDTools — 4x6 Crop + Circle BG</title>

<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.5.13/cropper.min.css"/>
<style>
  :root{
    --bg:#071025; --card:#061420; --accent:#06b6d4; --muted:#94a3b8; --panel:#0b1220;
  }
  html,body{height:100%;margin:0;font-family:Inter,system-ui,Roboto,Arial;background:linear-gradient(180deg,#071025,#06162a);color:#e6eef6}
  .app{max-width:1100px;margin:14px auto;padding:14px;border-radius:12px;background:rgba(255,255,255,0.02);box-shadow:0 10px 40px rgba(0,0,0,0.6)}
  header{display:flex;gap:12px;align-items:center}
  .logo{width:46px;height:46px;border-radius:10px;background:linear-gradient(90deg,#06b6d4,#7c3aed);display:flex;align-items:center;justify-content:center;font-weight:700}
  h1{margin:0;font-size:18px}
  .desc{color:var(--muted);font-size:13px}
  .main{display:flex;gap:12px;margin-top:12px;align-items:flex-start}
  /* left tools column */
  .tools{width:260px;background:var(--panel);padding:12px;border-radius:10px;box-sizing:border-box}
  .tools .group{margin-bottom:10px}
  .tools button, .tools input[type=range], .tools select, .tools input[type=color]{
    width:100%;margin-top:6px;padding:10px;border-radius:8px;border:1px solid rgba(255,255,255,0.03);background:rgba(255,255,255,0.02);color:var(--muted);cursor:pointer;
  }
  .tools label{font-size:13px;color:var(--muted)}
  .tools .small{font-size:12px;color:var(--muted)}
  /* right editor box */
  .editor{flex:1;background:var(--card);padding:12px;border-radius:10px;display:flex;flex-direction:column;align-items:center}
  .edit-box{width:320px;height:480px; /* 4x6 ratio: 4:6 -> 320x480 */ background:#081522;border-radius:8px;display:flex;align-items:center;justify-content:center;overflow:hidden;position:relative}
  .edit-box canvas, .edit-box img{max-width:100%;max-height:100%;display:block;}
  .placeholder{color:var(--muted)}
  .gallery{display:flex;gap:8px;flex-wrap:wrap;margin-top:10px}
  .thumb{width:64px;height:96px;border-radius:6px;overflow:hidden;border:2px solid transparent;cursor:pointer;background:#071827}
  .thumb img{width:100%;height:100%;object-fit:cover}
  .thumb.active{border-color:var(--accent)}
  .ocr-box{width:100%;margin-top:12px;background:rgba(0,0,0,0.12);padding:8px;border-radius:8px;color:var(--muted);max-height:140px;overflow:auto}
  footer{margin-top:12px;color:var(--muted);font-size:13px;text-align:center}
  .row{display:flex;gap:8px}
  .half{flex:1}
  @media (max-width:900px){
    .main{flex-direction:column}
    .tools{width:100%;display:flex;order:2}
    .editor{order:1;width:100%}
    .edit-box{width:100%;height:calc(100vw * 6 / 4);max-height:70vh}
  }
</style>
</head>
<body>
  <div class="app">
    <header>
      <div class="logo">ID</div>
      <div>
        <h1>Unknown IDTools</h1>
        <div class="desc">Crop locked to 4×6 (2:3). Tools left, editor right. New: Circle Background Changer.</div>
      </div>
    </header>

    <div class="main">
      <!-- LEFT: Tools -->
      <div class="tools" id="tools">
        <div class="group">
          <label class="small">Select files (JPG/PNG/PDF)</label>
          <input id="fileInput" type="file" accept=".jpg,.jpeg,.png,.pdf,image/*" multiple />
        </div>

        <div class="group">
          <label class="small">Crop / Edit</label>
          <button id="cropBtn">Apply Crop (4×6)</button>
          <div class="row" style="margin-top:8px">
            <button id="rotateLeft">⟲ Rotate</button>
            <button id="rotateRight">↻ Rotate</button>
          </div>
        </div>

        <div class="group">
          <label class="small">Enhance & Filters</label>
          <button id="autoEnhance">Auto Enhance</button>
          <button id="bwBtn">B / W</button>
          <button id="contrastBtn">Contrast +</button>
        </div>

        <div class="group">
          <label class="small">Background changer — Circle Tool</label>
          <label class="small">Background Color</label>
          <input type="color" id="bgColor" value="#ffffff"/>
          <label class="small" style="margin-top:6px">Background Image (optional)</label>
          <input type="file" id="bgImageInput" accept="image/*"/>
          <label class="small" style="margin-top:6px">Circle Radius</label>
          <input type="range" id="circleRadius" min="0.1" max="1" step="0.01" value="0.5"/>
          <label class="small" style="margin-top:6px">Drag center on preview to move circle</label>
          <button id="applyCircleBg" style="margin-top:8px">Apply Circle Background</button>
        </div>

        <div class="group">
          <label class="small">OCR & Export</label>
          <button id="ocrBtn">Run OCR</button>
          <div class="row" style="margin-top:8px">
            <button id="downloadPng" class="half">Download PNG</button>
            <button id="downloadJpg" class="half">Download JPG</button>
          </div>
          <button id="downloadPdf" style="margin-top:8px">Download PDF</button>
        </div>

        <div class="group">
          <label class="small">Gallery / Navigation</label>
          <div class="row">
            <button id="prevBtn">Prev</button>
            <button id="nextBtn">Next</button>
          </div>
        </div>

      </div>

      <!-- RIGHT: Editor -->
      <div class="editor">
        <div class="edit-box" id="editBox" style="width:320px;height:480px">
          <div id="placeholder" class="placeholder">No file selected — 4×6 preview</div>
          <img id="sourceImage" style="display:none;max-width:100%;max-height:100%;user-select:none" crossorigin="anonymous"/>
          <canvas id="workCanvas" style="display:none"></canvas>
          <!-- circle overlay for center/radius editing -->
          <canvas id="overlayCanvas" style="position:absolute;left:0;top:0;pointer-events:none"></canvas>
        </div>

        <div class="gallery" id="gallery"></div>

        <div class="ocr-box" id="ocrOutput">OCR output will appear here...</div>
      </div>
    </div>

    <footer>All work runs locally in browser. Recommended: Google Chrome.</footer>
  </div>

<!-- Libs -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.5.13/cropper.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/2.14.305/pdf.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/FileSaver.js/2.0.5/FileSaver.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/tesseract.js@4.1.1/dist/tesseract.min.js"></script>

<script>
/* Final updated script
 Features:
  - 4x6 locked crop (aspectRatio 2/3)
  - tools left, editor right
  - canvas editing size fixed to 800x1200 (but preview scaled to editBox)
  - circle background changer (center drag + radius)
  - multi-file gallery
  - OCR, Download PNG/JPG/PDF
*/

// elements
const fileInput = document.getElementById('fileInput');
const sourceImage = document.getElementById('sourceImage');
const workCanvas = document.getElementById('workCanvas');
const overlayCanvas = document.getElementById('overlayCanvas');
const editBox = document.getElementById('editBox');
const placeholderEl = document.querySelector('.edit-box #placeholder') || document.getElementById('placeholder');
const gallery = document.getElementById('gallery');
const ocrOutput = document.getElementById('ocrOutput');

const cropBtn = document.getElementById('cropBtn');
const rotateLeft = document.getElementById('rotateLeft');
const rotateRight = document.getElementById('rotateRight');
const autoEnhanceBtn = document.getElementById('autoEnhance');
const bwBtn = document.getElementById('bwBtn');
const contrastBtn = document.getElementById('contrastBtn');
const ocrBtn = document.getElementById('ocrBtn');
const downloadPng = document.getElementById('downloadPng');
const downloadJpg = document.getElementById('downloadJpg');
const downloadPdf = document.getElementById('downloadPdf');
const prevBtn = document.getElementById('prevBtn');
const nextBtn = document.getElementById('nextBtn');

const bgColorInput = document.getElementById('bgColor');
const bgImageInput = document.getElementById('bgImageInput');
const circleRadiusInput = document.getElementById('circleRadius');
const applyCircleBgBtn = document.getElementById('applyCircleBg');

let filesList = []; // {file, url, name}
let activeIndex = -1;
let cropper = null;
let overlayCtx = null;
let editingCanvasW = 800, editingCanvasH = 1200; // fixed 4x6 working size
let circleCenter = {x: 0.5, y: 0.5}; // relative center (0..1)
let circleRadius = 0.5; // relative radius (0..1)
let bgImage = null;

// setup overlay canvas size to match editBox
function resizeOverlay(){
  overlayCanvas.width = editBox.clientWidth;
  overlayCanvas.height = editBox.clientHeight;
  overlayCanvas.style.width = editBox.clientWidth + 'px';
  overlayCanvas.style.height = editBox.clientHeight + 'px';
  drawOverlay();
}
window.addEventListener('resize', resizeOverlay);
resizeOverlay();

// helpers
const clamp = v => Math.max(0, Math.min(255, Math.round(v)));

function clearCropper(){ if(cropper){ try{ cropper.destroy(); }catch(e){} cropper = null; } }

function setPlaceholderVisible(visible){
  placeholderEl.style.display = visible ? 'block' : 'none';
  sourceImage.style.display = visible ? 'none' : sourceImage.style.display;
  workCanvas.style.display = visible ? 'none' : workCanvas.style.display;
}

function addThumbnail(dataUrl, idx){
  const div = document.createElement('div'); div.className='thumb';
  const img = document.createElement('img'); img.src = dataUrl;
  div.appendChild(img);
  div.onclick = ()=> setActive(idx);
  gallery.appendChild(div);
  return div;
}
function refreshGallery(){
  Array.from(gallery.children).forEach((ch,i)=> ch.classList.toggle('active', i===activeIndex));
}

// when user selects files
fileInput.addEventListener('change', async (e)=>{
  const files = Array.from(e.target.files || []);
  if(!files.length) return;
  // reset
  filesList = []; gallery.innerHTML=''; activeIndex = -1; clearCropper();
  setPlaceholderVisible(true);

  for(const f of files){
    const name = f.name;
    if(f.type === 'application/pdf' || name.toLowerCase().endsWith('.pdf')){
      try{
        const ab = await f.arrayBuffer();
        const pdf = await pdfjsLib.getDocument({data:new Uint8Array(ab)}).promise;
        const page = await pdf.getPage(1);
        const viewport = page.getViewport({scale:1.4});
        const tmp = document.createElement('canvas');
        tmp.width = Math.round(viewport.width);
        tmp.height = Math.round(viewport.height);
        await page.render({canvasContext: tmp.getContext('2d'), viewport}).promise;
        const url = tmp.toDataURL('image/png');
        filesList.push({file:f, url, name});
        addThumbnail(url, filesList.length-1);
      }catch(err){
        console.error('PDF render error', err);
        alert('PDF render failed: '+name);
      }
    } else if(f.type.startsWith('image/') || /\.(jpe?g|png|gif|bmp|webp)$/i.test(name)){
      const url = URL.createObjectURL(f);
      filesList.push({file:f, url, name});
      addThumbnail(url, filesList.length-1);
    } else {
      alert('Unsupported: '+name);
    }
  }
  if(filesList.length) setActive(0);
});

// setActive: show image in sourceImage and init cropper
function setActive(index){
  if(index<0 || index>=filesList.length) return;
  activeIndex = index;
  refreshGallery();
  clearCropper();
  const item = filesList[index];
  sourceImage.onload = ()=> {
    // fit image into editBox while preserving aspect but cropper needs natural size
    initCropperFixed46();
    setPlaceholderVisible(false);
    resizeOverlay();
  };
  sourceImage.onerror = ()=> alert('Image load error');
  sourceImage.src = item.url;
}

// initialize cropper locked to 4x6 (aspect 2/3)
function initCropperFixed46(){
  clearCropper();
  // ensure image displayed
  sourceImage.style.display = 'block';
  workCanvas.style.display = 'none';
  cropper = new Cropper(sourceImage, {
    viewMode:1,
    autoCrop:true,
    aspectRatio: 4/6, // locked to 4x6 (2/3)
    background:true,
    responsive:true,
    movable:true,
    zoomable:true,
    rotatable:true,
    ready(){
      // set cropBox to match editBox display area
      // nothing special here; user can adjust
      drawOverlay();
    },
    crop(event){
      // update overlay if needed
      drawOverlay();
    }
  });
}

// apply crop: getCroppedCanvas to fixed editingCanvasW/H (800x1200)
cropBtn.addEventListener('click', ()=>{
  if(!cropper){ alert('No cropper ready'); return; }
  try{
    const cropped = cropper.getCroppedCanvas({width: editingCanvasW, height: editingCanvasH, imageSmoothingQuality:'high'});
    applyCanvasToWork(cropped);
    // replace current file url with cropped data for further editing
    const dataUrl = cropped.toDataURL('image/png');
    filesList[activeIndex].url = dataUrl;
    // update gallery thumbnail
    gallery.children[activeIndex].querySelector('img').src = dataUrl;
    // destroy cropper so further tools operate on canvas
    clearCropper();
  }catch(err){
    console.error(err);
    alert('Crop failed: '+err.message);
  }
});

// draw canvas element
function applyCanvasToWork(canvasEl){
  workCanvas.width = canvasEl.width; workCanvas.height = canvasEl.height;
  workCanvas.style.width = editBox.clientWidth + 'px';
  workCanvas.style.height = editBox.clientHeight + 'px';
  const cctx = workCanvas.getContext('2d'); cctx.clearRect(0,0,workCanvas.width, workCanvas.height);
  cctx.drawImage(canvasEl,0,0);
  workCanvas.style.display = 'block';
  sourceImage.style.display = 'none';
  drawOverlay();
}

// Rotate (if cropper exists rotate, else rotate canvas image)
rotateLeft.addEventListener('click', ()=> rotateActive(-90));
rotateRight.addEventListener('click', ()=> rotateActive(90));
function rotateActive(deg){
  if(cropper){
    cropper.rotate(deg);
    return;
  }
  // rotate workCanvas content
  if(workCanvas.style.display === 'none' && sourceImage.src){
    // draw image into canvas then rotate
    const img = new Image(); img.onload = ()=>{
      const tmp = document.createElement('canvas'); tmp.width = img.naturalHeight; tmp.height = img.naturalWidth;
      const tctx = tmp.getContext('2d'); tctx.translate(tmp.width/2,tmp.height/2); tctx.rotate(deg*Math.PI/180);
      tctx.drawImage(img, -img.naturalWidth/2, -img.naturalHeight/2);
      applyCanvasToWork(tmp);
      filesList[activeIndex].url = tmp.toDataURL('image/png');
      gallery.children[activeIndex].querySelector('img').src = filesList[activeIndex].url;
    }; img.src = filesList[activeIndex].url;
  } else if(workCanvas.style.display !== 'none'){
    const tmp = document.createElement('canvas'); tmp.width = workCanvas.height; tmp.height = workCanvas.width;
    const tctx = tmp.getContext('2d'); tctx.translate(tmp.width/2,tmp.height/2); tctx.rotate(deg*Math.PI/180);
    tctx.drawImage(workCanvas, -workCanvas.width/2, -workCanvas.height/2);
    applyCanvasToWork(tmp);
    filesList[activeIndex].url = tmp.toDataURL('image/png');
    gallery.children[activeIndex].querySelector('img').src = filesList[activeIndex].url;
  }
}

// Auto enhance: brightness+contrast then sharpening conv
autoEnhanceBtn.addEventListener('click', ()=>{
  if(workCanvas.style.display === 'none'){
    // draw current image to canvas first (from filesList url)
    const img = new Image(); img.onload = ()=>{
      const tmp = document.createElement('canvas'); tmp.width = editingCanvasW; tmp.height = editingCanvasH;
      const tctx = tmp.getContext('2d'); tctx.drawImage(img, 0, 0, tmp.width, tmp.height);
      applyCanvasToWork(tmp);
      enhanceCanvas();
    }; img.src = filesList[activeIndex].url;
  } else enhanceCanvas();
});

function enhanceCanvas(){
  try{
    const cctx = workCanvas.getContext('2d');
    let id = cctx.getImageData(0,0,workCanvas.width, workCanvas.height);
    const d = id.data;
    const brightness = 1.08, contrast = 1.12;
    for(let i=0;i<d.length;i+=4){
      for(let ch=0; ch<3; ch++){
        let v = (d[i+ch] - 128) * contrast + 128;
        v = v * brightness;
        d[i+ch] = clamp(v);
      }
    }
    cctx.putImageData(id,0,0);
    // simple sharpen kernel
    const kernel = [-1,-1,-1,-1,9,-1,-1,-1,-1];
    convolve(workCanvas, kernel, 1, 0);
    filesList[activeIndex].url = workCanvas.toDataURL('image/png');
    gallery.children[activeIndex].querySelector('img').src = filesList[activeIndex].url;
  }catch(e){ console.error(e); alert('Enhance failed'); }
}

// convolution helper
function convolve(canvasEl, kernel, factor=1, bias=0){
  const cw = canvasEl.width, ch = canvasEl.height;
  const ctx2 = canvasEl.getContext('2d');
  const src = ctx2.getImageData(0,0,cw,ch);
  const dst = ctx2.createImageData(cw,ch);
  const s = src.data, d = dst.data;
  const kw = Math.sqrt(kernel.length), half = Math.floor(kw/2);
  for(let y=0;y<ch;y++){
    for(let x=0;x<cw;x++){
      let r=0,g=0,b=0;
      for(let ky=0; ky<kw; ky++){
        for(let kx=0; kx<kw; kx++){
          const px = x + kx - half, py = y + ky - half;
          if(px>=0 && px<cw && py>=0 && py<ch){
            const idx = (py*cw + px)*4;
            const kval = kernel[ky*kw + kx];
            r += s[idx] * kval;
            g += s[idx+1] * kval;
            b += s[idx+2] * kval;
          }
        }
      }
      const idx2 = (y*cw + x)*4;
      d[idx2]   = clamp(factor * r + bias);
      d[idx2+1] = clamp(factor * g + bias);
      d[idx2+2] = clamp(factor * b + bias);
      d[idx2+3] = s[idx2+3];
    }
  }
  ctx2.putImageData(dst,0,0);
}

// B/W
bwBtn.addEventListener('click', ()=>{
  if(workCanvas.style.display === 'none'){
    const img = new Image(); img.onload = ()=>{
      const tmp = document.createElement('canvas'); tmp.width = editingCanvasW; tmp.height = editingCanvasH;
      tmp.getContext('2d').drawImage(img,0,0,tmp.width,tmp.height);
      applyCanvasToWork(tmp);
      applyBW();
    }; img.src = filesList[activeIndex].url;
  } else applyBW();
});
function applyBW(){
  const cctx = workCanvas.getContext('2d');
  let id = cctx.getImageData(0,0,workCanvas.width, workCanvas.height);
  const d = id.data;
  for(let i=0;i<d.length;i+=4){
    const v = 0.299*d[i] + 0.587*d[i+1] + 0.114*d[i+2];
    const t = 140;
    const val = v>t?255:0;
    d[i]=d[i+1]=d[i+2]=val;
  }
  cctx.putImageData(id,0,0);
  filesList[activeIndex].url = workCanvas.toDataURL('image/png');
  gallery.children[activeIndex].querySelector('img').src = filesList[activeIndex].url;
}

// Contrast
contrastBtn.addEventListener('click', ()=>{
  if(workCanvas.style.display === 'none'){
    const img = new Image(); img.onload = ()=>{
      const tmp = document.createElement('canvas'); tmp.width = editingCanvasW; tmp.height = editingCanvasH;
      tmp.getContext('2d').drawImage(img,0,0,tmp.width,tmp.height);
      applyCanvasToWork(tmp);
      applyContrast(1.2);
    }; img.src = filesList[activeIndex].url;
  } else applyContrast(1.2);
});
function applyContrast(factor){
  const cctx = workCanvas.getContext('2d');
  let id = cctx.getImageData(0,0,workCanvas.width, workCanvas.height);
  const d = id.data;
  for(let i=0;i<d.length;i+=4){
    for(let ch=0; ch<3; ch++){
      d[i+ch] = clamp((d[i+ch] - 128) * factor + 128);
    }
  }
  cctx.putImageData(id,0,0);
  filesList[activeIndex].url = workCanvas.toDataURL('image/png');
  gallery.children[activeIndex].querySelector('img').src = filesList[activeIndex].url;
}

// OCR (Tesseract)
ocrBtn.addEventListener('click', async ()=>{
  try{
    ocrOutput.textContent = 'Reading...';
    // ensure canvas has data
    if(workCanvas.style.display === 'none'){
      const img = new Image(); img.crossOrigin='anonymous';
      img.onload = ()=>{ workCanvas.width = editingCanvasW; workCanvas.height = editingCanvasH; workCanvas.getContext('2d').drawImage(img,0,0,workCanvas.width,workCanvas.height); runOCR(); };
      img.src = filesList[activeIndex].url;
    } else runOCR();
  }catch(e){ ocrOutput.textContent = 'OCR failed'; console.error(e); }
});
async function runOCR(){
  try{
    const blob = await new Promise(res => workCanvas.toBlob(res,'image/png'));
    const { createWorker } = Tesseract;
    const worker = createWorker({ logger: m => {/*progress*/} });
    await worker.load(); await worker.loadLanguage('eng'); await worker.initialize('eng');
    const { data: { text } } = await worker.recognize(blob);
    await worker.terminate();
    ocrOutput.textContent = text || 'No text found';
  }catch(e){ ocrOutput.textContent = 'OCR error'; console.error(e); }
}

// Downloads
downloadPng.addEventListener('click', ()=> saveCurrent('image/png','idcard.png'));
downloadJpg.addEventListener('click', ()=> saveCurrent('image/jpeg','idcard.jpg'));
downloadPdf.addEventListener('click', ()=> saveCurrent('pdf','idcard.pdf'));

function saveCurrent(type, name){
  // ensure canvas
  if(workCanvas.style.display === 'none'){
    const img = new Image(); img.onload = ()=>{ workCanvas.width = editingCanvasW; workCanvas.height = editingCanvasH; workCanvas.getContext('2d').drawImage(img,0,0); finalizeSave(type,name); };
    img.src = filesList[activeIndex].url;
  } else finalizeSave(type,name);
}
function finalizeSave(type,name){
  workCanvas.toBlob(blob=>{
    if(type === 'pdf'){
      const { jsPDF } = window.jspdf;
      const pdf = new jsPDF({orientation: workCanvas.width>workCanvas.height?'l':'p', unit:'px', format:[workCanvas.width, workCanvas.height]});
      const dataUrl = workCanvas.toDataURL('image/png');
      pdf.addImage(dataUrl,'PNG',0,0,workCanvas.width,workCanvas.height);
      pdf.save(name);
    } else {
      saveAs(blob, name);
    }
  }, type, 0.95);
}

// prev / next
prevBtn.addEventListener('click', ()=> { if(filesList.length===0) return; setActive((activeIndex-1+filesList.length)%filesList.length); });
nextBtn.addEventListener('click', ()=> { if(filesList.length===0) return; setActive((activeIndex+1)%filesList.length); });

// Overlay drawing for Circle Tool
function drawOverlay(){
  if(!overlayCtx) overlayCtx = overlayCanvas.getContext('2d');
  overlayCtx.clearRect(0,0,overlayCanvas.width, overlayCanvas.height);
  // show circle overlay only when image visible (sourceImage or canvas)
  const visible = sourceImage.style.display !== 'none' || workCanvas.style.display !== 'none';
  if(!visible) return;
  // compute circle in overlay coords from relative center & radius
  const cw = overlayCanvas.width, ch = overlayCanvas.height;
  const cx = circleCenter.x * cw, cy = circleCenter.y * ch;
  const r = circleRadius * Math.min(cw,ch);
  // translucent mask outside circle
  overlayCtx.fillStyle = 'rgba(0,0,0,0.35)';
  overlayCtx.beginPath();
  overlayCtx.rect(0,0,cw,ch);
  overlayCtx.arc(cx,cy,r,0,Math.PI*2,true);
  overlayCtx.fill('evenodd');
  // circle border
  overlayCtx.strokeStyle = '#06b6d4';
  overlayCtx.lineWidth = 2;
  overlayCtx.beginPath(); overlayCtx.arc(cx,cy,r,0,Math.PI*2); overlayCtx.stroke();
}

// allow dragging center on preview
let dragging = false;
overlayCanvas.addEventListener('pointerdown', (e)=>{
  const rect = overlayCanvas.getBoundingClientRect();
  const x = e.clientX - rect.left, y = e.clientY - rect.top;
  circleCenter.x = x / overlayCanvas.width; circleCenter.y = y / overlayCanvas.height;
  dragging = true; drawOverlay();
});
window.addEventListener('pointermove', (e)=>{
  if(!dragging) return;
  const rect = overlayCanvas.getBoundingClientRect();
  const x = e.clientX - rect.left, y = e.clientY - rect.top;
  circleCenter.x = Math.max(0, Math.min(1, x / overlayCanvas.width));
  circleCenter.y = Math.max(0, Math.min(1, y / overlayCanvas.height));
  drawOverlay();
});
window.addEventListener('pointerup', ()=> dragging = false);

// radius input
circleRadiusInput.addEventListener('input', ()=> { circleRadius = parseFloat(circleRadiusInput.value); drawOverlay(); });

// bg image load
bgImageInput.addEventListener('change', async (e)=>{
  const f = e.target.files[0];
  if(!f) return;
  const url = URL.createObjectURL(f);
  const img = new Image(); img.onload = ()=> { bgImage = img; URL.revokeObjectURL(url); }; img.src = url;
});

// Apply circle background: keep circle area from current image, outside replaced by color or bgImage
applyCircleBgBtn.addEventListener('click', ()=>{
  if(activeIndex<0) { alert('No image'); return; }
  // ensure we have base image on canvas
  const baseImg = new Image();
  baseImg.crossOrigin = 'anonymous';
  baseImg.onload = ()=> {
    // draw base image fit to editingCanvasW/H
    const tmp = document.createElement('canvas'); tmp.width = editingCanvasW; tmp.height = editingCanvasH;
    const tctx = tmp.getContext('2d');
    tctx.fillStyle = '#fff'; tctx.fillRect(0,0,tmp.width,tmp.height);
    tctx.drawImage(baseImg, 0, 0, tmp.width, tmp.height);
    // prepare background (color or image)
    const bgCanvas = document.createElement('canvas'); bgCanvas.width = tmp.width; bgCanvas.height = tmp.height;
    const bgc = bgCanvas.getContext('2d');
    // color
    const color = bgColorInput.value || '#ffffff'; bgc.fillStyle = color; bgc.fillRect(0,0,bgCanvas.width,bgCanvas.height);
    // if bgImage present, draw it covering canvas
    if(bgImage){
      // draw bgImage centered cover
      const imgRatio = bgImage.width / bgImage.height;
      const cw = bgCanvas.width, ch = bgCanvas.height;
      let dw = cw, dh = cw / imgRatio;
      if(dh < ch){ dh = ch; dw = ch * imgRatio; }
      const dx = (cw - dw)/2, dy = (ch - dh)/2;
      bgc.drawImage(bgImage, dx, dy, dw, dh);
    }
    // circle region in pixels
    const cx = Math.round(circleCenter.x * tmp.width);
    const cy = Math.round(circleCenter.y * tmp.height);
    const r = Math.round(circleRadius * Math.min(tmp.width, tmp.height));
    // create final canvas: put bg first, then draw circular clipped image on top
    const final = document.createElement('canvas'); final.width = tmp.width; final.height = tmp.height;
    const fctx = final.getContext('2d');
    // draw background
    fctx.drawImage(bgCanvas,0,0);
    // clip circle and draw image inside
    fctx.save();
    fctx.beginPath();
    fctx.arc(cx, cy, r, 0, Math.PI*2);
    fctx.closePath();
    fctx.clip();
    fctx.drawImage(tmp, 0,0);
    fctx.restore();
    // optional: add smooth transition edge? For now hard circle - user requested circle tool.
    // apply to workCanvas
    applyCanvasToWork(final);
    filesList[activeIndex].url = final.toDataURL('image/png');
    gallery.children[activeIndex].querySelector('img').src = filesList[activeIndex].url;
    clearCropper();
  };
  // choose source: if workCanvas visible use its data, else use filesList url
  if(workCanvas.style.display !== 'none'){
    const dataUrl = workCanvas.toDataURL('image/png');
    baseImg.src = dataUrl;
  } else {
    baseImg.src = filesList[activeIndex].url;
  }
});

// overlay redraw initial
drawOverlay();

// when clicking thumbnail -> setActive by index handled in addThumbnail

// ensure overlay canvas sized to editBox and positioned
function fitPreviewElements(){
  const boxRect = editBox.getBoundingClientRect();
  overlayCanvas.style.left = editBox.offsetLeft + 'px';
  overlayCanvas.style.top = editBox.offsetTop + 'px';
  overlayCanvas.width = editBox.clientWidth;
  overlayCanvas.height = editBox.clientHeight;
  overlayCanvas.style.position = 'absolute';
  overlayCanvas.style.pointerEvents = 'auto';
  overlayCanvas.style.zIndex = 5;
}
function updatePreviewSizing(){
  // scale visible image/canvas to fit editBox while preserving aspect ratio
  const ebW = editBox.clientWidth, ebH = editBox.clientHeight;
  // update sourceImage size automatically via CSS; for canvas we set style to fit
  if(workCanvas.style.display !== 'none'){
    workCanvas.style.width = ebW + 'px';
    workCanvas.style.height = ebH + 'px';
  }
  if(sourceImage.style.display !== 'none'){
    sourceImage.style.width = ebW + 'px';
    sourceImage.style.height = ebH + 'px';
  }
  overlayCanvas.style.width = ebW + 'px';
  overlayCanvas.style.height = ebH + 'px';
  overlayCanvas.width = ebW;
  overlayCanvas.height = ebH;
  drawOverlay();
}
window.addEventListener('resize', updatePreviewSizing);
setTimeout(updatePreviewSizing, 300);

// initial placeholder
setPlaceholderVisible(true);

</script>
</body>
</html>
