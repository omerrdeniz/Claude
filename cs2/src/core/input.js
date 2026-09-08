// Klavye/fare girişi ve pointer lock yönetimi.

export class Input {
  constructor(element) {
    this.element = element;
    this.down = new Set();
    this.pressedKeys = new Set();
    this.mouse = {
      dx: 0, dy: 0,
      left: false, right: false,
      leftPressed: false, rightPressed: false,
      wheel: 0,
    };
    this.locked = false;
    this.onLockChange = null;
    this.onKeyPress = null;
    this.enabled = true;

    this._onKeyDown = (e) => {
      if (e.repeat) { e.preventDefault(); return; }
      this.down.add(e.code);
      this.pressedKeys.add(e.code);
      if (this.onKeyPress) this.onKeyPress(e);
      if (['Tab', 'Space', 'F1', 'F2', 'F5'].includes(e.code) || e.code.startsWith('Arrow')) e.preventDefault();
    };
    this._onKeyUp = (e) => { this.down.delete(e.code); };
    this._onMouseDown = (e) => {
      if (!this.locked) return;
      if (e.button === 0) { this.mouse.left = true; this.mouse.leftPressed = true; }
      if (e.button === 2) { this.mouse.right = true; this.mouse.rightPressed = true; }
    };
    this._onMouseUp = (e) => {
      if (e.button === 0) this.mouse.left = false;
      if (e.button === 2) this.mouse.right = false;
    };
    this._onMouseMove = (e) => {
      if (!this.locked) return;
      this.mouse.dx += e.movementX || 0;
      this.mouse.dy += e.movementY || 0;
    };
    this._onWheel = (e) => {
      if (!this.locked) return;
      this.mouse.wheel += Math.sign(e.deltaY);
      e.preventDefault();
    };
    this._onContext = (e) => e.preventDefault();
    this._onLockChange = () => {
      this.locked = document.pointerLockElement === this.element;
      if (!this.locked) {
        this.down.clear();
        this.mouse.left = false;
        this.mouse.right = false;
      }
      if (this.onLockChange) this.onLockChange(this.locked);
    };

    window.addEventListener('keydown', this._onKeyDown);
    window.addEventListener('keyup', this._onKeyUp);
    window.addEventListener('mousedown', this._onMouseDown);
    window.addEventListener('mouseup', this._onMouseUp);
    window.addEventListener('mousemove', this._onMouseMove);
    window.addEventListener('wheel', this._onWheel, { passive: false });
    window.addEventListener('contextmenu', this._onContext);
    document.addEventListener('pointerlockchange', this._onLockChange);
    window.addEventListener('blur', () => { this.down.clear(); });
  }

  requestLock() {
    if (!this.locked && this.element.requestPointerLock) {
      const res = this.element.requestPointerLock();
      if (res && typeof res.catch === 'function') res.catch(() => {});
    }
  }

  exitLock() {
    if (this.locked && document.exitPointerLock) document.exitPointerLock();
  }

  isDown(code) { return this.down.has(code); }
  wasPressed(code) { return this.pressedKeys.has(code); }

  // Her karenin sonunda çağrılır: anlık (pressed) durumları ve fare deltasını sıfırlar.
  endFrame() {
    this.pressedKeys.clear();
    this.mouse.dx = 0;
    this.mouse.dy = 0;
    this.mouse.wheel = 0;
    this.mouse.leftPressed = false;
    this.mouse.rightPressed = false;
  }
}
