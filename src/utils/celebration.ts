import confetti from 'canvas-confetti';

export interface CelebrationOptions {
  origin?: { x: number; y: number };
  intensity?: 'subtle' | 'milestone' | 'grand';
}

/**
 * Fires a subtle, tasteful celebratory confetti effect using Handelha's calming brand palette.
 * Keeps particles small and gravity natural so it delights without jarring or cluttering.
 */
export const fireGoalCelebration = (
  event?: React.MouseEvent | { clientX: number; clientY: number } | null,
  options?: CelebrationOptions
) => {
  const intensity = options?.intensity || 'subtle';

  let originX = 0.5;
  let originY = 0.5;

  if (options?.origin) {
    originX = options.origin.x;
    originY = options.origin.y;
  } else if (event && 'clientX' in event && event.clientX > 0) {
    originX = Math.max(0.05, Math.min(0.95, event.clientX / window.innerWidth));
    originY = Math.max(0.05, Math.min(0.95, event.clientY / window.innerHeight));
  }

  // Handelha's mindful palette: deep sage, warm mint, mindful amber, calm lavender, soft gold
  const brandColors = ['#2F6F68', '#4EA392', '#88C6B9', '#D3782D', '#E2BF84', '#7773A1'];

  try {
    if (intensity === 'grand') {
      // Gentle dual burst for 100% daily milestone completion
      confetti({
        particleCount: 35,
        spread: 60,
        origin: { x: Math.max(0.2, originX - 0.1), y: originY },
        colors: brandColors,
        scalar: 0.8,
        ticks: 120,
        gravity: 0.95,
        disableForReducedMotion: true,
      });
      setTimeout(() => {
        confetti({
          particleCount: 35,
          spread: 60,
          origin: { x: Math.min(0.8, originX + 0.1), y: originY },
          colors: brandColors,
          scalar: 0.8,
          ticks: 120,
          gravity: 0.95,
          disableForReducedMotion: true,
        });
      }, 150);
    } else if (intensity === 'milestone') {
      confetti({
        particleCount: 26,
        spread: 50,
        origin: { x: originX, y: originY },
        colors: brandColors,
        scalar: 0.75,
        ticks: 100,
        gravity: 1.1,
        disableForReducedMotion: true,
      });
    } else {
      // Subtle micro-burst directly around the checked target
      confetti({
        particleCount: 18,
        spread: 45,
        origin: { x: originX, y: originY },
        colors: brandColors,
        scalar: 0.7,
        ticks: 90,
        gravity: 1.15,
        disableForReducedMotion: true,
      });
    }
  } catch (err) {
    // Non-fatal if canvas or context unavailable
    console.debug('Confetti animation suppressed:', err);
  }
};
