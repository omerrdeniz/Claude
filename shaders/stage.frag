// The playfield's ground: a field of colour that belongs to the piece being
// played, with a pool of light where the notes land.
//
// Done on the GPU because everything this game does not do — glow, bloom, a
// background that moves — it does not do for one reason: drawn on the CPU it
// costs more per frame than the notes themselves. A fragment shader colours
// every pixel at once and asks nothing of the frame budget.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;    // the stage, in pixels
uniform float uTime;   // seconds since the song began
uniform float uHeat;   // how far into a streak the player is, 0 to 1
uniform vec3 uTop;     // the colour of the far end
uniform vec3 uBottom;  // the colour underfoot
uniform vec3 uGlow;    // the pool where the notes land
uniform float uLine;   // where the hit line is, 0 at the top and 1 at the foot

out vec4 fragColor;

void main() {
  vec2 p = FlutterFragCoord().xy / uSize;

  // The ground, darkening downwards, with the horizon slightly curved so it
  // reads as a space rather than a wall.
  float depth = p.y + 0.06 * (1.0 - cos((p.x - 0.5) * 3.14159));
  vec3 col = mix(uTop, uBottom, clamp(depth, 0.0, 1.0));

  // Never quite still. Slow enough that nothing about it is ever the thing
  // the eye is watching.
  float breath = 0.5 + 0.5 * sin(uTime * 0.6);

  // The pool of light on the floor, widening and brightening with a streak.
  vec2 d = (p - vec2(0.5, uLine)) * vec2(1.0, 1.9 - 0.4 * uHeat);
  float pool = exp(-dot(d, d) * (9.0 - 3.5 * uHeat));
  col += uGlow * pool * (0.30 + 0.45 * uHeat + 0.06 * breath);

  // A second, tighter core right on the line, so the landing place is always
  // the brightest thing on the ground.
  vec2 core = (p - vec2(0.5, uLine)) * vec2(0.45, 7.0);
  col += uGlow * exp(-dot(core, core) * 6.0) * (0.20 + 0.30 * uHeat);

  fragColor = vec4(col, 1.0);
}
