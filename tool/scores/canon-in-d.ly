\version "2.18.2"

% A piano arrangement of Pachelbel's canon, assembled from the Mutopia
% edition's own part files.
%
% The canon is written for three violins over a ground bass, so there is no
% keyboard edition to take. The transcription this library used first folded
% all four parts onto two staves — faithful, and up to four notes thick in
% the right hand at every eighth. It is a reading score, not a piano piece,
% and it did not sound like the Canon in D anybody knows.
%
% This is the arrangement everyone actually means: the leading voice in the
% right hand, the ground bass in the left. Both come from the edition
% unchanged — nothing here is invented, only chosen. The second and third
% violins are left out because they chase the first through the same octave;
% on a keyboard they collide with it rather than harmonise.

\include "violin_one.ily"
\include "violoncello.ily"

\score {
  \new PianoStaff <<
    \new Staff { \clef treble \violinone }
    \new Staff { \clef bass \violoncello }
  >>
  \midi { \tempo 4 = 55 }
}
