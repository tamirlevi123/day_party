import axios from 'axios';
import { URL } from 'url';
import { isIP } from 'net';

export type ExternalVideoProvider = 'youtube' | 'vimeo' | 'other';

export interface VideoPreview {
  provider: ExternalVideoProvider;
  providerId: string | null;
  normalizedUrl: string;
  title: string | null;
  description: string | null;
  durationSec: number | null;
  thumbnailUrl: string | null;
  embedHtml: string | null;
  metadata: Record<string, unknown> | null;
}

const YOUTUBE_DOMAINS = ['youtube.com', 'www.youtube.com', 'm.youtube.com', 'youtu.be', 'www.youtu.be'];
const VIMEO_DOMAINS = ['vimeo.com', 'www.vimeo.com', 'player.vimeo.com'];

const isPrivateHostname = (hostname: string): boolean => {
  const lowerHost = hostname.toLowerCase();

  if (lowerHost === 'localhost' || lowerHost.endsWith('.local')) {
    return true;
  }

  const ipVersion = isIP(lowerHost);
  if (ipVersion) {
    if (lowerHost === '::1') {
      return true;
    }

    if (ipVersion === 4) {
      if (
        lowerHost.startsWith('10.') ||
        lowerHost.startsWith('127.') ||
        lowerHost.startsWith('169.254.') ||
        lowerHost.startsWith('192.168.') ||
        /^172\.(1[6-9]|2\d|3[0-1])\./.test(lowerHost)
      ) {
        return true;
      }
    }

    if (ipVersion === 6) {
      if (lowerHost.startsWith('fc') || lowerHost.startsWith('fd')) {
        return true;
      }
    }
  }

  return false;
};

const sanitiseEmbedHtml = (html?: string | null): string | null => {
  if (!html) return null;
  // Remove any script tags for safety
  return html.replace(/<script[\s\S]*?>[\s\S]*?<\/script>/gi, '');
};

const normaliseUrl = (rawUrl: string): URL => {
  let url: URL;
  try {
    url = new URL(rawUrl);
  } catch {
    throw new Error('Invalid URL format');
  }

  if (!['http:', 'https:'].includes(url.protocol)) {
    throw new Error('Only HTTP(S) URLs are allowed');
  }

  if (isPrivateHostname(url.hostname)) {
    throw new Error('Links to private networks are not allowed');
  }

  return url;
};

const extractYouTubeId = (url: URL): string | null => {
  if (url.hostname === 'youtu.be') {
    const id = url.pathname.slice(1);
    return id ? id.split('/')[0] : null;
  }

  if (url.searchParams.has('v')) {
    return url.searchParams.get('v');
  }

  if (url.pathname.includes('/embed/')) {
    return url.pathname.split('/embed/')[1]?.split('/')[0] || null;
  }

  return null;
};

const extractVimeoId = (url: URL): string | null => {
  const match = url.pathname.match(/\/(video\/)?(\d+)/);
  return match ? match[2] : null;
};

const fetchOEmbed = async (endpoint: string): Promise<Record<string, unknown>> => {
  const response = await axios.get(endpoint, {
    timeout: 5000,
    headers: {
      'User-Agent': 'DayPartyBot/1.0 (+https://dayparty.work.gd)',
      Accept: 'application/json',
    },
  });

  return response.data as Record<string, unknown>;
};

const buildPreviewFromOEmbed = (
  provider: ExternalVideoProvider,
  providerId: string | null,
  normalizedUrl: string,
  oEmbed: Record<string, unknown>,
): VideoPreview => {
  const title = typeof oEmbed.title === 'string' ? oEmbed.title : null;
  const description = typeof oEmbed.author_name === 'string' ? oEmbed.author_name : null;
  const thumbnailUrl = typeof oEmbed.thumbnail_url === 'string' ? oEmbed.thumbnail_url : null;
  const html = typeof oEmbed.html === 'string' ? oEmbed.html : null;

  let durationSec: number | null = null;
  if (typeof oEmbed.duration === 'number') {
    durationSec = oEmbed.duration;
  } else if (typeof oEmbed.duration === 'string' && oEmbed.duration.trim() !== '') {
    const parsed = Number(oEmbed.duration);
    durationSec = Number.isFinite(parsed) ? parsed : null;
  }

  return {
    provider,
    providerId,
    normalizedUrl,
    title,
    description,
    durationSec,
    thumbnailUrl,
    embedHtml: sanitiseEmbedHtml(html),
    metadata: oEmbed,
  };
};

export const getVideoPreview = async (rawUrl: string): Promise<VideoPreview> => {
  const url = normaliseUrl(rawUrl);
  const hostname = url.hostname.toLowerCase();

  if (YOUTUBE_DOMAINS.includes(hostname)) {
    const videoId = extractYouTubeId(url);
    if (!videoId) {
      throw new Error('Unable to extract YouTube video ID');
    }

    const normalizedUrl = `https://www.youtube.com/watch?v=${videoId}`;
    const oEmbed = await fetchOEmbed(`https://www.youtube.com/oembed?url=${encodeURIComponent(normalizedUrl)}&format=json`);
    return buildPreviewFromOEmbed('youtube', videoId, normalizedUrl, oEmbed);
  }

  if (VIMEO_DOMAINS.includes(hostname)) {
    const videoId = extractVimeoId(url);
    if (!videoId) {
      throw new Error('Unable to extract Vimeo video ID');
    }

    const normalizedUrl = `https://vimeo.com/${videoId}`;
    const oEmbed = await fetchOEmbed(`https://vimeo.com/api/oembed.json?url=${encodeURIComponent(normalizedUrl)}`);
    return buildPreviewFromOEmbed('vimeo', videoId, normalizedUrl, oEmbed);
  }

  // Fallback for other providers: basic metadata
  const normalizedUrl = url.toString();
  return {
    provider: 'other',
    providerId: null,
    normalizedUrl,
    title: null,
    description: null,
    durationSec: null,
    thumbnailUrl: null,
    embedHtml: null,
    metadata: null,
  };
};

