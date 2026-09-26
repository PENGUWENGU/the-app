export interface LatLng {
  lat: number;
  lng: number;
}

export interface SpoofedLocation extends LatLng {
  altitude: number; // in meters
  speed: number; // in meters per second
  heading: number; // in degrees 0-360
  horizontalAccuracy: number; // in meters
  verticalAccuracy: number; // in meters
  timestamp: number;
}

export type TravelModeType = 'walk' | 'run' | 'cycle' | 'drive' | 'custom';

export interface TravelModeConfig {
  id: TravelModeType;
  title: string;
  icon: string;
  baseSpeed: number; // m/s
  speedKmh: number;
  description: string;
}

export interface Waypoint extends LatLng {
  id: string;
  name?: string;
  altitude?: number;
  speed?: number;
}

export interface RouteTrack {
  id: string;
  name: string;
  description?: string;
  waypoints: Waypoint[];
  distanceMeters: number;
  estimatedDurationSeconds: number;
  mode: 'walk' | 'drive' | 'cycle';
  createdAt: number;
}

export interface FavoriteLocation {
  id: string;
  name: string;
  lat: number;
  lng: number;
  tag: 'landmark' | 'gaming' | 'test' | 'custom';
  description?: string;
  createdAt: number;
}

export interface DvtRpcLog {
  id: string;
  timestamp: string;
  direction: 'in' | 'out' | 'system';
  service: 'locationd' | 'DVTLocationSimulation' | 'LocalDevVPN' | 'idevice_pair';
  action: string;
  details: string;
}

export type MapTheme = 'dark' | 'standard' | 'satellite' | 'terrain';

export interface SimulationSettings {
  naturalSpeedJitter: boolean; // Random realistic +/- 5-10% speed variance
  naturalGpsDrift: boolean; // Subtle 1-3m jitter mimicking satellite atmospheric drift
  keepAliveAudio: boolean; // Background silent audio heartbeat
  autoHeadingCorrection: boolean; // Automatically face heading toward movement
  joystickSensitivity: number; // 0.5 to 2.0 multiplier
  customSpeedMps: number;
  hapticsEnabled: boolean;
  soundEffects: boolean;
  developerTunnelIp: string;
  developerTunnelPort: number;
  loopbackConnected: boolean;
}
