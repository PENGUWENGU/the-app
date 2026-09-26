import { LatLng, Waypoint, RouteTrack } from '../types';

/**
 * Calculates Haversine distance between two coordinates in meters
 */
export function calculateDistance(coord1: LatLng, coord2: LatLng): number {
  const R = 6371e3; // Earth radius in meters
  const φ1 = (coord1.lat * Math.PI) / 180;
  const φ2 = (coord2.lat * Math.PI) / 180;
  const Δφ = ((coord2.lat - coord1.lat) * Math.PI) / 180;
  const Δλ = ((coord2.lng - coord1.lng) * Math.PI) / 180;

  const a =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
}

/**
 * Calculates bearing (heading) in degrees from point A to point B
 */
export function calculateBearing(start: LatLng, end: LatLng): number {
  const startLat = (start.lat * Math.PI) / 180;
  const startLng = (start.lng * Math.PI) / 180;
  const endLat = (end.lat * Math.PI) / 180;
  const endLng = (end.lng * Math.PI) / 180;

  const dLng = endLng - startLng;

  const y = Math.sin(dLng) * Math.cos(endLat);
  const x =
    Math.cos(startLat) * Math.sin(endLat) -
    Math.sin(startLat) * Math.cos(endLat) * Math.cos(dLng);

  let brng = (Math.atan2(y, x) * 180) / Math.PI;
  return (brng + 360) % 360;
}

/**
 * Calculates destination point given starting point, distance (meters) and bearing (degrees)
 */
export function calculateDestination(start: LatLng, distanceMeters: number, bearingDegrees: number): LatLng {
  const R = 6371e3; // Earth radius in meters
  const δ = distanceMeters / R;
  const θ = (bearingDegrees * Math.PI) / 180;
  const φ1 = (start.lat * Math.PI) / 180;
  const λ1 = (start.lng * Math.PI) / 180;

  const sinφ1 = Math.sin(φ1);
  const cosφ1 = Math.cos(φ1);
  const sinδ = Math.sin(δ);
  const cosδ = Math.cos(δ);
  const sinθ = Math.sin(θ);
  const cosθ = Math.cos(θ);

  const sinφ2 = sinφ1 * cosδ + cosφ1 * sinδ * cosθ;
  const φ2 = Math.asin(sinφ2);
  const y = sinθ * sinδ * cosφ1;
  const x = cosδ - sinφ1 * sinφ2;
  const λ2 = λ1 + Math.atan2(y, x);

  return {
    lat: (φ2 * 180) / Math.PI,
    lng: (((λ2 * 180) / Math.PI + 540) % 360) - 180,
  };
}

/**
 * Formats coordinates for display (e.g. 37.7749° N, 122.4194° W)
 */
export function formatCoordinates(lat: number, lng: number): string {
  const latDir = lat >= 0 ? 'N' : 'S';
  const lngDir = lng >= 0 ? 'E' : 'W';
  return `${Math.abs(lat).toFixed(6)}° ${latDir}, ${Math.abs(lng).toFixed(6)}° ${lngDir}`;
}

/**
 * Searches locations using OpenStreetMap Nominatim
 */
export async function searchPlaces(query: string): Promise<Array<{
  name: string;
  displayName: string;
  lat: number;
  lng: number;
  type: string;
}>> {
  if (!query || query.trim().length < 2) return [];
  try {
    const res = await fetch(
      `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(
        query.trim()
      )}&limit=6&addressdetails=1`,
      {
        headers: {
          'Accept-Language': 'en',
        },
      }
    );
    if (!res.ok) return [];
    const data = await res.json();
    return data.map((item: any) => ({
      name: item.name || item.display_name.split(',')[0],
      displayName: item.display_name,
      lat: parseFloat(item.lat),
      lng: parseFloat(item.lon),
      type: item.type || 'place',
    }));
  } catch (err) {
    console.warn('Geocoding search failed:', err);
    return [];
  }
}

/**
 * Reverse geocodes a coordinate to an address
 */
export async function reverseGeocode(lat: number, lng: number): Promise<string> {
  try {
    const res = await fetch(
      `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}&zoom=16&addressdetails=1`,
      {
        headers: {
          'Accept-Language': 'en',
        },
      }
    );
    if (!res.ok) return `${lat.toFixed(5)}, ${lng.toFixed(5)}`;
    const data = await res.json();
    return data.display_name || `${lat.toFixed(5)}, ${lng.toFixed(5)}`;
  } catch {
    return `${lat.toFixed(5)}, ${lng.toFixed(5)}`;
  }
}

/**
 * Fetches realistic road network route using OSRM with interpolation
 */
export async function fetchOsrmRoute(
  waypoints: LatLng[],
  profile: 'walking' | 'driving' | 'cycling' = 'walking'
): Promise<{ coordinates: LatLng[]; distance: number; duration: number }> {
  if (waypoints.length < 2) {
    return { coordinates: waypoints, distance: 0, duration: 0 };
  }

  // Format: {lng},{lat};{lng},{lat}
  const coordinatesStr = waypoints.map((wp) => `${wp.lng},${wp.lat}`).join(';');
  const url = `https://router.project-osrm.org/route/v1/${profile}/${coordinatesStr}?overview=full&geometries=geojson`;

  try {
    const res = await fetch(url);
    if (!res.ok) throw new Error('OSRM error');
    const data = await res.json();
    if (data.code === 'Ok' && data.routes && data.routes.length > 0) {
      const route = data.routes[0];
      const coords: LatLng[] = route.geometry.coordinates.map((pt: [number, number]) => ({
        lat: pt[1],
        lng: pt[0],
      }));
      return {
        coordinates: coords,
        distance: route.distance,
        duration: route.duration,
      };
    }
  } catch (err) {
    console.warn('OSRM route fetch fallback to interpolated line:', err);
  }

  // Fallback: interpolate points directly
  const interpolated: LatLng[] = [];
  let totalDist = 0;
  for (let i = 0; i < waypoints.length - 1; i++) {
    const p1 = waypoints[i];
    const p2 = waypoints[i + 1];
    const segDist = calculateDistance(p1, p2);
    totalDist += segDist;
    const steps = Math.max(5, Math.floor(segDist / 20));
    for (let s = 0; s < steps; s++) {
      const frac = s / steps;
      interpolated.push({
        lat: p1.lat + (p2.lat - p1.lat) * frac,
        lng: p1.lng + (p2.lng - p1.lng) * frac,
      });
    }
  }
  interpolated.push(waypoints[waypoints.length - 1]);

  return {
    coordinates: interpolated,
    distance: totalDist,
    duration: totalDist / (profile === 'driving' ? 13.4 : profile === 'cycling' ? 6.5 : 1.4),
  };
}

/**
 * Builds standard GPX XML content
 */
export function exportToGpx(route: RouteTrack): string {
  const time = new Date().toISOString();
  const trkpts = route.waypoints
    .map(
      (wp, idx) => `      <trkpt lat="${wp.lat}" lon="${wp.lng}">
        <ele>${wp.altitude || 10}</ele>
        <time>${new Date(Date.now() + idx * 2000).toISOString()}</time>
      </trkpt>`
    )
    .join('\n');

  return `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Locus iOS Simulator" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata>
    <name>${escapeXml(route.name)}</name>
    <desc>${escapeXml(route.description || 'Exported from Locus iOS Location Simulator')}</desc>
    <time>${time}</time>
  </metadata>
  <trk>
    <name>${escapeXml(route.name)}</name>
    <trkseg>
${trkpts}
    </trkseg>
  </trk>
</gpx>`;
}

function escapeXml(unsafe: string): string {
  return unsafe.replace(/[<>&'"]/g, (c) => {
    switch (c) {
      case '<':
        return '&lt;';
      case '>':
        return '&gt;';
      case '&':
        return '&amp;';
      case '\'':
        return '&apos;';
      case '"':
        return '&quot;';
      default:
        return c;
    }
  });
}

/**
 * Parses a GPX XML string into waypoints
 */
export function parseGpx(xmlContent: string): { name: string; waypoints: Waypoint[] } {
  const parser = new DOMParser();
  const xmlDoc = parser.parseFromString(xmlContent, 'text/xml');
  const name = xmlDoc.querySelector('name')?.textContent || 'Imported GPX Track';

  const pts: Waypoint[] = [];
  const trkpts = xmlDoc.querySelectorAll('trkpt, rtept, wpt');

  trkpts.forEach((pt, index) => {
    const lat = parseFloat(pt.getAttribute('lat') || '0');
    const lng = parseFloat(pt.getAttribute('lon') || '0');
    const ele = parseFloat(pt.querySelector('ele')?.textContent || '10');
    if (!isNaN(lat) && !isNaN(lng) && lat !== 0 && lng !== 0) {
      pts.push({
        id: `gpx-${index}-${Date.now()}`,
        lat,
        lng,
        altitude: ele,
      });
    }
  });

  return { name, waypoints: pts };
}

/**
 * Web Audio API synthesizer for sound effects
 */
let audioCtx: AudioContext | null = null;

export function playSound(type: 'teleport' | 'click' | 'step' | 'toggle' | 'alert') {
  try {
    if (!audioCtx) {
      const AudioCtxClass = window.AudioContext || (window as any).webkitAudioContext;
      if (AudioCtxClass) {
        audioCtx = new AudioCtxClass();
      }
    }
    if (!audioCtx || audioCtx.state === 'suspended') {
      audioCtx?.resume();
    }
    if (!audioCtx) return;

    const now = audioCtx.currentTime;

    if (type === 'teleport') {
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(440, now);
      osc.frequency.exponentialRampToValueAtTime(880, now + 0.12);
      osc.frequency.exponentialRampToValueAtTime(1320, now + 0.25);
      gain.gain.setValueAtTime(0.15, now);
      gain.gain.exponentialRampToValueAtTime(0.01, now + 0.28);
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start(now);
      osc.stop(now + 0.3);
    } else if (type === 'click') {
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(900, now);
      osc.frequency.exponentialRampToValueAtTime(200, now + 0.03);
      gain.gain.setValueAtTime(0.08, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.04);
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start(now);
      osc.stop(now + 0.05);
    } else if (type === 'step') {
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(320, now);
      gain.gain.setValueAtTime(0.04, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.03);
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start(now);
      osc.stop(now + 0.04);
    } else if (type === 'toggle') {
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(587.33, now);
      osc.frequency.setValueAtTime(880, now + 0.05);
      gain.gain.setValueAtTime(0.08, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.12);
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start(now);
      osc.stop(now + 0.14);
    } else if (type === 'alert') {
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(350, now);
      osc.frequency.setValueAtTime(220, now + 0.1);
      gain.gain.setValueAtTime(0.1, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.2);
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start(now);
      osc.stop(now + 0.22);
    }
  } catch (e) {
    // Audio not allowed or unavailable
  }
}
