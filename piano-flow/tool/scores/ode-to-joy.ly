\version "2.24.0"

% Piano Flow's own arrangement, and the only one in the library that is.
%
% The theme is written for cellos and basses in the Ninth, so there is no
% piano edition to copy — every keyboard version of it is somebody's
% arrangement. This is ours: the complete sixteen-bar theme, all four
% phrases, set in C rather than Beethoven's D so the tune stays on white
% keys. The tempo is his own: Allegro assai, half note = 80, so the quarter
% is 160.
%
% Absolute pitches, not \relative: this is short enough to read at a glance
% and an octave slip in a hand-written score is exactly the mistake that got
% into the Bach prelude before the editions were used.

\header {
  title = "Neşeye Övgü"
  composer = "Ludwig van Beethoven"
}

% The phrase that opens three of the four lines.
opening = { e'4 e' f' g' | g' f' e' d' | c' c' d' e' | }

% The chords under it: tonic, then a turn to the dominant.
openingChords = {
  <c e g>2 <c e g> | <c e g> <g, b, d> | <c e g> <g, b, d> |
}

right = {
  \key c \major
  \time 4/4
  \opening e'4. d'8 d'2 |          % line one, open on the dominant
  \opening d'4. c'8 c'2 |          % line two, home
  d'4 d' e' c' |                   % line three, the middle phrase
  d'4 e'8 f' e'4 c' |
  d'4 e'8 f' e'4 d' |
  c'4 d' g2 |
  \opening d'4. c'8 c'2 |          % line four, closing
}

left = {
  \key c \major
  \time 4/4
  \openingChords <g, b, d>1 |
  \openingChords <g, b, d>2 <c e g> |
  <g, b, d>1 | <c e g>2 <g, b, d> | <g, b, d>1 | <c e g>2 <g, b, d> |
  \openingChords <g, b, d>2 <c e g> |
}

\score {
  \new PianoStaff <<
    \new Staff { \clef treble \right }
    \new Staff { \clef bass \left }
  >>
  \midi { \tempo 4 = 160 }
}
