// Procedural human form for three.js.
//
//   import { createHuman } from './human.js';
//   const human = createHuman();          // THREE.Group, feet on y = 0, facing +z
//   scene.add(human);
//   human.userData.joints.elbowL.rotation.x = -1.2;   // pose it
//
// Units are metres. The figure's left side is +x.

import * as THREE from 'three';

const BASE_HEIGHT = 1.75;

// Builds a smooth closed surface through a stack of elliptical cross-sections.
// Each section is [y, rx, rz, cx = 0, cz = 0]: height, half-width, half-depth,
// and the centre offset of the ellipse. Sections are interpolated with a
// Catmull-Rom spline parameterised by y, so uneven spacing stays smooth.
function loft(sections, { radial = 28, steps = 6, mirror = 1 } = {}) {
  const s = sections
    .map(([y, rx, rz, cx = 0, cz = 0]) => [y, rx, rz, cx * mirror, cz])
    .sort((a, b) => a[0] - b[0]);
  const n = s.length;

  const tangent = (i, k) => {
    const a = s[Math.max(i - 1, 0)];
    const b = s[Math.min(i + 1, n - 1)];
    return (b[k] - a[k]) / (b[0] - a[0]);
  };

  const rings = [];
  for (let i = 0; i < n - 1; i++) {
    const p0 = s[i];
    const p1 = s[i + 1];
    const h = p1[0] - p0[0];
    const last = i === n - 2 ? steps : steps - 1;
    for (let j = 0; j <= last; j++) {
      const t = j / steps;
      const t2 = t * t;
      const t3 = t2 * t;
      const ring = [p0[0] + h * t];
      for (let k = 1; k < 5; k++) {
        ring.push(
          (2 * t3 - 3 * t2 + 1) * p0[k] +
            (t3 - 2 * t2 + t) * h * tangent(i, k) +
            (-2 * t3 + 3 * t2) * p1[k] +
            (t3 - t2) * h * tangent(i + 1, k)
        );
      }
      ring[1] = Math.max(ring[1], 1e-4);
      ring[2] = Math.max(ring[2], 1e-4);
      rings.push(ring);
    }
  }

  const positions = [];
  const indices = [];
  for (const [y, rx, rz, cx, cz] of rings) {
    for (let j = 0; j < radial; j++) {
      const a = (j / radial) * Math.PI * 2;
      positions.push(cx + rx * Math.cos(a), y, cz + rz * Math.sin(a));
    }
  }
  for (let k = 0; k < rings.length - 1; k++) {
    for (let j = 0; j < radial; j++) {
      const a = k * radial + j;
      const b = k * radial + ((j + 1) % radial);
      const c = a + radial;
      const d = b + radial;
      indices.push(a, c, b, b, c, d);
    }
  }

  // End caps.
  const first = rings[0];
  const lastRing = rings[rings.length - 1];
  const bottom = positions.length / 3;
  positions.push(first[3], first[0], first[4]);
  const top = bottom + 1;
  positions.push(lastRing[3], lastRing[0], lastRing[4]);
  const topStart = (rings.length - 1) * radial;
  for (let j = 0; j < radial; j++) {
    const j1 = (j + 1) % radial;
    indices.push(bottom, j, j1);
    indices.push(top, topStart + j1, topStart + j);
  }

  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.setIndex(indices);
  geometry.computeVertexNormals();
  return geometry;
}

export function createHuman({ height = BASE_HEIGHT, color = 0xc9b8a6, material } = {}) {
  const skin =
    material ?? new THREE.MeshStandardMaterial({ color, roughness: 0.78, metalness: 0 });

  const human = new THREE.Group();
  human.name = 'human';
  const joints = {};

  const joint = (name, parent, x, y, z) => {
    const g = new THREE.Group();
    g.name = name;
    g.position.set(x, y, z);
    parent.add(g);
    joints[name] = g;
    return g;
  };

  const part = (name, parent, geometry) => {
    const mesh = new THREE.Mesh(geometry, skin);
    mesh.name = name;
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    parent.add(mesh);
    return mesh;
  };

  // ---- Torso -------------------------------------------------------------
  const hips = joint('hips', human, 0, 0, 0);
  part(
    'torso',
    hips,
    loft(
      [
        [0.8, 0.03, 0.035, 0, -0.004],
        [0.83, 0.085, 0.078, 0, -0.008],
        [0.88, 0.15, 0.106, 0, -0.014],
        [0.95, 0.168, 0.116, 0, -0.016],
        [1.03, 0.155, 0.102, 0, -0.006],
        [1.1, 0.136, 0.09, 0, 0],
        [1.2, 0.15, 0.1, 0, 0.004],
        [1.3, 0.17, 0.116, 0, 0.01],
        [1.38, 0.176, 0.106, 0, 0.002],
        [1.43, 0.168, 0.09, 0, -0.006],
        [1.468, 0.108, 0.068, 0, -0.01],
        [1.505, 0.05, 0.05, 0, -0.01],
      ],
      { radial: 40 }
    )
  );

  // ---- Neck and head -----------------------------------------------------
  const neck = joint('neck', hips, 0, 1.47, 0);
  part(
    'neck',
    neck,
    loft([
      [-0.03, 0.052, 0.052, 0, -0.012],
      [0, 0.05, 0.052, 0, -0.008],
      [0.05, 0.046, 0.05, 0, 0],
      [0.11, 0.045, 0.05, 0, 0.006],
    ])
  );

  const head = joint('head', neck, 0, 0.06, 0.012);
  part(
    'skull',
    head,
    loft(
      [
        [0.0, 0.01, 0.01, 0, 0.056],
        [0.01, 0.034, 0.034, 0, 0.046],
        [0.035, 0.055, 0.066, 0, 0.02],
        [0.07, 0.066, 0.083, 0, 0.008],
        [0.11, 0.073, 0.094, 0, 0],
        [0.15, 0.076, 0.098, 0, -0.004],
        [0.185, 0.068, 0.088, 0, -0.006],
        [0.208, 0.046, 0.06, 0, -0.006],
        [0.22, 0.01, 0.012, 0, -0.006],
      ],
      { radial: 36 }
    )
  );
  part(
    'nose',
    head,
    loft(
      [
        [0.07, 0.003, 0.003, 0, 0.09],
        [0.079, 0.013, 0.014, 0, 0.093],
        [0.092, 0.009, 0.011, 0, 0.091],
        [0.125, 0.006, 0.007, 0, 0.088],
        [0.136, 0.002, 0.002, 0, 0.088],
      ],
      { radial: 12 }
    )
  );
  for (const side of [1, -1]) {
    const ear = part(side > 0 ? 'earL' : 'earR', head, new THREE.SphereGeometry(1, 14, 10));
    ear.scale.set(0.008, 0.029, 0.016);
    ear.position.set(side * 0.074, 0.103, -0.008);
    ear.rotation.set(-0.2, side * -0.25, 0);
  }

  // ---- Arms --------------------------------------------------------------
  const arm = (suffix, side) => {
    const shoulder = joint('shoulder' + suffix, hips, side * 0.182, 1.382, -0.004);
    part(
      'upperArm' + suffix,
      shoulder,
      loft([
        [0.056, 0.02, 0.02],
        [0.04, 0.046, 0.05],
        [0, 0.056, 0.06],
        [-0.08, 0.049, 0.055],
        [-0.18, 0.042, 0.047],
        [-0.27, 0.036, 0.038],
        [-0.31, 0.034, 0.035],
      ])
    );

    const elbow = joint('elbow' + suffix, shoulder, 0, -0.29, 0);
    part(
      'forearm' + suffix,
      elbow,
      loft([
        [0.035, 0.03, 0.032],
        [0, 0.036, 0.038],
        [-0.06, 0.038, 0.041],
        [-0.14, 0.03, 0.035],
        [-0.22, 0.021, 0.027],
        [-0.25, 0.019, 0.026],
        [-0.275, 0.018, 0.025],
      ])
    );

    // Palm faces the thigh, so the hand is thin in x and wide in z.
    const wrist = joint('wrist' + suffix, elbow, 0, -0.25, 0);
    part(
      'palm' + suffix,
      wrist,
      loft(
        [
          [0.012, 0.016, 0.023],
          [-0.03, 0.014, 0.037],
          [-0.07, 0.012, 0.042],
          [-0.094, 0.011, 0.04],
          [-0.102, 0.006, 0.034],
        ],
        { radial: 16 }
      )
    );

    // Fingers: index (front) to little (back), curling gently toward the palm.
    const fingers = [
      [0.03, 0.07, 0.0088],
      [0.0105, 0.079, 0.0092],
      [-0.0095, 0.073, 0.0088],
      [-0.029, 0.057, 0.0078],
    ];
    fingers.forEach(([z, len, r], i) => {
      const finger = part(
        `finger${i}${suffix}`,
        wrist,
        loft(
          [
            [0.006, r, r, 0, 0],
            [-len * 0.35, r, r, -0.003, 0],
            [-len * 0.7, r * 0.92, r * 0.92, -0.011, 0],
            [-len * 0.96, r * 0.8, r * 0.8, -0.021, 0],
            [-len, r * 0.3, r * 0.3, -0.023, 0],
          ],
          { radial: 10, steps: 4, mirror: side }
        )
      );
      finger.position.set(0, -0.094, z);
    });
    const thumb = part(
      'thumb' + suffix,
      wrist,
      loft(
        [
          [0.01, 0.012, 0.014],
          [-0.03, 0.011, 0.012],
          [-0.056, 0.009, 0.0095],
          [-0.064, 0.003, 0.003],
        ],
        { radial: 10, steps: 4 }
      )
    );
    thumb.position.set(side * -0.004, -0.028, 0.03);
    thumb.rotation.set(-0.6, 0, side * -0.25);

    // Relaxed hang: slightly away from the body, elbow a little bent.
    shoulder.rotation.z = side * 0.13;
    shoulder.rotation.x = 0.04;
    elbow.rotation.x = -0.2;
    wrist.rotation.x = -0.05;
  };
  arm('L', 1);
  arm('R', -1);

  // ---- Legs --------------------------------------------------------------
  const leg = (suffix, side) => {
    const hip = joint('hip' + suffix, hips, side * 0.088, 0.9, 0);
    part(
      'thigh' + suffix,
      hip,
      loft(
        [
          [0.05, 0.03, 0.03, 0, -0.006],
          [0, 0.08, 0.088, 0, -0.006],
          [-0.1, 0.08, 0.087, 0, -0.002],
          [-0.25, 0.066, 0.071, 0, 0.002],
          [-0.37, 0.053, 0.056, 0, 0],
          [-0.42, 0.05, 0.054, 0, 0.002],
          [-0.46, 0.046, 0.05, 0, 0],
        ],
        { radial: 32 }
      )
    );

    const knee = joint('knee' + suffix, hip, 0, -0.42, 0);
    part(
      'shin' + suffix,
      knee,
      loft([
        [0.04, 0.044, 0.048, 0, 0],
        [0, 0.05, 0.055, 0, 0.004],
        [-0.1, 0.05, 0.058, 0, -0.012],
        [-0.2, 0.043, 0.048, 0, -0.01],
        [-0.32, 0.03, 0.034, 0, -0.004],
        [-0.4, 0.027, 0.031, 0, 0],
        [-0.44, 0.026, 0.03, 0, 0],
      ])
    );

    // Foot is lofted heel-to-toe, then laid flat with the sole on the floor.
    const ankle = joint('ankle' + suffix, knee, 0, -0.4, 0);
    const floor = -0.08;
    const footGeometry = loft(
      [
        [-0.066, 0.01, 0.012],
        [-0.056, 0.027, 0.034],
        [-0.02, 0.034, 0.046],
        [0.03, 0.036, 0.04],
        [0.09, 0.042, 0.027, 0.003],
        [0.14, 0.046, 0.018, 0.004],
        [0.176, 0.04, 0.013, 0.002],
        [0.19, 0.02, 0.008, 0],
      ].map(([z, rx, ry, cx = 0]) => [z, rx, ry, cx, -(floor + ry)]),
      { radial: 20, mirror: side }
    );
    footGeometry.rotateX(Math.PI / 2);
    footGeometry.computeVertexNormals();
    part('foot' + suffix, ankle, footGeometry);

    hip.rotation.z = side * 0.015;
    ankle.rotation.y = side * 0.14;
    ankle.rotation.z = side * -0.015; // keeps the sole flat under the splayed leg
  };
  leg('L', 1);
  leg('R', -1);

  human.userData.joints = joints;
  human.scale.setScalar(height / BASE_HEIGHT);
  return human;
}
