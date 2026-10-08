import type { ImageMetadata } from 'astro';
import desktopHome from '../assets/screenshots/desktop/home.webp';
import mobileHome from '../assets/screenshots/mobile/home.webp';

export interface Screenshot {
  src: ImageMetadata;
  alt: string;
}

export const screenshots = {
  desktopHome: {
    src: desktopHome,
    alt: 'Sentorr home on desktop: a trending movie spotlight with Play and More info, above the Trending now row',
  },
  mobileHome: {
    src: mobileHome,
    alt: 'Sentorr home on a phone: the spotlight, Trending now and bottom navigation',
  },
} satisfies Record<string, Screenshot>;
