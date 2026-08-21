const http = require('http');
const path = require('path');
const tf = require('@tensorflow/tfjs-node');
const ort = require('onnxruntime-node');
const Human = require('@vladmandic/human');

let human = null;
let yoloSession = null;
let referenceEmbedding = null;
let similarityEMA = null;

const COCO_LABELS = ["person","bicycle","car","motorcycle","airplane","bus","train","truck","boat","traffic light","fire hydrant","stop sign","parking meter","bench","bird","cat","dog","horse","sheep","cow","elephant","bear","zebra","giraffe","backpack","umbrella","handbag","tie","suitcase","frisbee","skis","snowboard","sports ball","kite","baseball bat","baseball glove","skateboard","surfboard","tennis racket","bottle","wine glass","cup","fork","knife","spoon","bowl","banana","apple","sandwich","orange","broccoli","carrot","hot dog","pizza","donut","cake","chair","couch","potted plant","bed","dining table","toilet","tv","laptop","mouse","remote","keyboard","cell phone","microwave","oven","toaster","sink","refrigerator","book","clock","vase","scissors","teddy bear","hair drier","toothbrush"];

const config = {
  backend: 'tensorflow',
  modelBasePath: 'file://' + path.join(__dirname, 'models'),
  async: false,
  filter: { enabled: true, flip: true },
  face: {
    enabled: true,
    detector: { enabled: true, rotation: false },
    mesh: { enabled: true },
    iris: { enabled: true },
    embedder: { enabled: true },
    emotion: { enabled: true },
    attention: { enabled: false },
  },
  hand: { enabled: true },
  body: { enabled: true },
};

async function init() {
  human = new Human.Human(config);
  await human.tf.ready();
  await human.load();
  yoloSession = await ort.InferenceSession.create(path.join(__dirname, 'models', 'yolov8n.onnx'));
  console.log('HUMAN READY', 'human', human.version, 'tf', tf.version_core, 'yolo', 'yolov8n');
}

function cosineSim(a, b) {
  let dot = 0, na = 0, nb = 0;
  for (let i = 0; i < a.length; i++) { dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i]; }
  const n = Math.sqrt(na) * Math.sqrt(nb);
  return n === 0 ? 0 : dot / n;
}

function boxOf(f) {
  if (!f) return null;
  if (f.box && typeof f.box === 'object' && f.box.x !== undefined) return f.box;
  if (Array.isArray(f.box)) return { x: f.box[0], y: f.box[1], width: f.box[2], height: f.box[3] };
  return null;
}

function irisLookingAway(annotations) {
  const eyes = [
    { eye: annotations.leftEye, iris: annotations.leftEyeIris },
    { eye: annotations.rightEye, iris: annotations.rightEyeIris },
  ];
  for (const { eye, iris } of eyes) {
    if (!eye || !iris || eye.length < 2 || iris.length < 1) continue;
    const a = eye[0];
    const b = eye[eye.length - 1];
    const axis = { x: b.x - a.x, y: b.y - a.y };
    const len2 = axis.x * axis.x + axis.y * axis.y;
    if (len2 === 0) continue;
    const irisPt = iris[0];
    const t = ((irisPt.x - a.x) * axis.x + (irisPt.y - a.y) * axis.y) / len2;
    const perp = { x: -axis.y, y: axis.x };
    const offset = ((irisPt.x - a.x) * perp.x + (irisPt.y - a.y) * perp.y) / Math.sqrt(len2);
    const eyeLen = Math.sqrt(len2);
    if (t < 0.3 || t > 0.7) return true;
    if (Math.abs(offset) > 0.35 * eyeLen) return true;
  }
  return false;
}

async function yoloDetect(tensor) {
  if (!yoloSession) return [];
  const [H, W] = [tensor.shape[0], tensor.shape[1]];
  const data = await tensor.data();
  const TARGET = 640;
  const scale = Math.min(TARGET / W, TARGET / H);
  const nw = Math.round(W * scale), nh = Math.round(H * scale);
  const padX = Math.round((TARGET - nw) / 2), padY = Math.round((TARGET - nh) / 2);
  const input = new Float32Array(3 * TARGET * TARGET);
  for (let y = 0; y < nh; y++) {
    for (let x = 0; x < nw; x++) {
      const si = (y * W + x) * 3;
      const di = y * TARGET + x;
      input[di] = data[si] / 255;
      input[TARGET * TARGET + di] = data[si + 1] / 255;
      input[2 * TARGET * TARGET + di] = data[si + 2] / 255;
    }
  }
  const feeds = {};
  feeds[yoloSession.inputNames[0]] = new ort.Tensor('float32', input, [1, 3, TARGET, TARGET]);
  const out = await yoloSession.run(feeds);
  const outName = yoloSession.outputNames[0];
  const pred = out[outName].data;
  const dims = out[outName].dims;
  const npred = dims[2];
  // The focus app only needs to know whether a *cell phone* is near the
  // person's face. Scoring all 80 COCO classes and running NMS on every
  // object wastes most of the inference time and can make the live panel
  // stutter. COCO's cell-phone class is 67.
  const PHONE_CLASS = 67;

  const boxes = [], scores = [], labels = [];
  for (let i = 0; i < npred; i++) {
    // YOLOv8 ONNX export already emits sigmoided class probabilities in
    // [0,1] — applying another sigmoid here maps every score into the
    // 0.5–0.73 band and floods the result with thousands of false hits.
    const score = pred[(4 + PHONE_CLASS) * npred + i];
    if (score < 0.45) continue;
    const cx = pred[i], cy = pred[npred + i], w = pred[2 * npred + i], h = pred[3 * npred + i];
    boxes.push([(cx - w / 2 - padX) / scale, (cy - h / 2 - padY) / scale, (cx + w / 2 - padX) / scale, (cy + h / 2 - padY) / scale]);
    scores.push(score);
    labels.push(PHONE_CLASS);
  }

  const order = boxes.map((_, i) => i).sort((a, b) => scores[b] - scores[a]);
  const keep = [];
  while (order.length) {
    const i = order.shift();
    keep.push(i);
    const rest = order.filter((j) => {
      const a = boxes[i], b = boxes[j];
      const x1 = Math.max(a[0], b[0]), y1 = Math.max(a[1], b[1]);
      const x2 = Math.min(a[2], b[2]), y2 = Math.min(a[3], b[3]);
      const inter = Math.max(0, x2 - x1) * Math.max(0, y2 - y1);
      const areaA = (a[2] - a[0]) * (a[3] - a[1]);
      const areaB = (b[2] - b[0]) * (b[3] - b[1]);
      const iou = inter / (areaA + areaB - inter + 1e-9);
      return iou < 0.45;
    });
    order.length = 0;
    order.push(...rest);
  }
  return keep.map((i) => ({ label: COCO_LABELS[labels[i]] || 'unknown', score: scores[i], box: boxes[i] }));
}

function analyze(result) {
  const faces = result.face || [];
  const hands = result.hand || [];
  const bodies = result.body || [];
  const person = faces.length > 0 || bodies.length > 0;
  const f = faces[0];
  let yaw = 0, pitch = 0, roll = 0, lookingAway = false;
  if (f) {
    const hp = (f.userData && f.userData.headPose) || f.headPose || null;
    if (hp) {
      yaw = hp.yaw || 0;
      pitch = hp.pitch || 0;
      roll = hp.roll || 0;
      lookingAway = Math.abs(yaw) > 0.45 || Math.abs(pitch) > 0.35;
    }
    if (!lookingAway && f.annotations) {
      lookingAway = irisLookingAway(f.annotations);
    }
  }
  let phoneUse = false;
  const fb = boxOf(f);
  if (faces.length && hands.length && fb) {
    for (const h of hands) {
      const hb = boxOf(h);
      if (!hb) continue;
      const ox = Math.max(0, Math.min(fb.x + fb.width, hb.x + hb.width) - Math.max(fb.x, hb.x));
      const faceLowerY = fb.y + fb.height * 0.4;
      const oy = Math.max(0, Math.min(fb.y + fb.height, hb.y + hb.height) - Math.max(faceLowerY, hb.y));
      const faceArea = fb.width * fb.height;
      if (ox > 0 && oy > 0 && (ox * oy) / faceArea > 0.08) phoneUse = true;
    }
  }
  let pose = 'unknown';
  const b = bodies[0];
  if (b) {
    const kp = b.keypoints || [];
    const get = (p) => kp.find((k) => k.part === p);
    const ankleL = get('left_ankle'), ankleR = get('right_ankle');
    const hipL = get('left_hip'), hipR = get('right_hip');
    const nose = get('nose');
    if (ankleL && ankleR && hipL) {
      const ankleY = (ankleL.position.y + ankleR.position.y) / 2;
      const hipY = (hipL.position.y + (hipR ? hipR.position.y : hipL.position.y)) / 2;
      pose = ankleY > hipY + 40 ? 'standing' : 'sitting';
    } else if (nose) {
      pose = 'sitting';
    }
  }
  let similarity = null;
  let embeddingSeen = false;
  if (f && f.embedding) {
    const emb = Array.from(f.embedding);
    embeddingSeen = true;
    if (!referenceEmbedding) {
      referenceEmbedding = emb;
      similarityEMA = null;
    } else if (Math.abs(yaw) < 0.3 && Math.abs(pitch) < 0.25) {
      const rawSim = cosineSim(emb, referenceEmbedding);
      similarityEMA = similarityEMA == null ? rawSim : 0.7 * similarityEMA + 0.3 * rawSim;
      if (rawSim > 0.85) {
        for (let i = 0; i < referenceEmbedding.length; i++) {
          referenceEmbedding[i] = 0.97 * referenceEmbedding[i] + 0.03 * emb[i];
        }
      }
      similarity = similarityEMA;
    } else {
      similarity = similarityEMA;
    }
  }
  const emotion = f && f.emotion && f.emotion.score ? f.emotion : null;
  const attention = f && f.attention && f.attention.score ? f.attention : null;
  return {
    person,
    faces: faces.length,
    hands: hands.length,
    bodies: bodies.length,
    yaw: round(yaw), pitch: round(pitch), roll: round(roll),
    lookingAway,
    phoneUse,
    pose,
    similarity: similarity == null ? null : round(Math.max(0, Math.min(1, similarity))),
    embeddingSeen,
    emotion,
    attention,
  };
}

function round(x) {
  if (typeof x !== 'number') return 0;
  return Math.round(x * 100) / 100;
}

function sendJSON(res, code, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(code, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) });
  res.end(body);
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    return sendJSON(res, 200, { ok: true, human: human ? 'ready' : 'loading', yolo: yoloSession ? 'ready' : 'loading' });
  }
  if (req.method === 'POST' && req.url === '/analyze') {
    let body = [];
    req.on('data', (c) => body.push(c));
    req.on('end', async () => {
      try {
        const payload = JSON.parse(Buffer.concat(body).toString('utf8'));
        if (!payload.image) return sendJSON(res, 400, { error: 'missing image' });
        const buffer = Buffer.from(payload.image, 'base64');
        let tensor;
        try {
          tensor = tf.node.decodeImage(buffer, 3);
        } catch (e) {
          return sendJSON(res, 400, { error: 'decode failed: ' + e.message });
        }
        const result = await human.detect(tensor);
        const objects = await yoloDetect(tensor);
        tensor.dispose();
        const verdict = analyze(result);
        const faceBox = boxOf(result.face && result.face[0]);
        const phones = objects.filter((o) => o.label === 'cell phone' && o.score > 0.55);
        if (phones.length) {
          const nearFace = phones.some((p) => {
            const pb = p.box;
            if (!pb) return false;
            if (faceBox) {
              const fx = faceBox.x + faceBox.width / 2;
              const fy = faceBox.y + faceBox.height / 2;
              const px = (pb[0] + pb[2]) / 2;
              const py = (pb[1] + pb[3]) / 2;
              const dx = Math.abs(fx - px);
              const dy = Math.abs(fy - py);
              // Boundary: the phone must be within one face-size of the face
              // center — anything further away is not "using" it.
              const reach = Math.max(faceBox.width, faceBox.height) * 1.0;
              return dx < reach && dy < reach;
            }
            return true;
          });
          if (nearFace) verdict.phoneUse = true;
        }
        console.log('ANALYZE', new Date().toISOString(), JSON.stringify(verdict), 'yolo=', JSON.stringify(objects.map((o) => o.label + ':' + Math.round(o.score * 100))));
        sendJSON(res, 200, { ok: true, verdict, objects });
      } catch (e) {
        sendJSON(res, 500, { error: e.message });
      }
    });
    return;
  }
  sendJSON(res, 404, { error: 'not found' });
});

init().then(() => {
  server.listen(8765, '127.0.0.1', () => console.log('HUMAN SERVER LISTENING on 127.0.0.1:8765'));
}).catch((e) => {
  console.error('FATAL INIT', e);
  process.exit(1);
});
