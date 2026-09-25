import React, { useState, useEffect, useRef } from 'react';
import { 
  Navigation, 
  Compass, 
  MapPin, 
  Settings as SettingsIcon, 
  Star, 
  Play, 
  Square, 
  Trash2, 
  Download, 
  Search, 
  X, 
  Sun, 
  Moon, 
  Laptop, 
  Copy, 
  Check, 
  Clock, 
  Gauge, 
  Layers, 
  Share2,
  FolderGit2
} from 'lucide-react';
import L from 'leaflet';

interface Waypoint {
  lat: number;
  lng: number;
}

interface SavedRoute {
  id: string;
  name: string;
  distanceMeters: number;
  waypoints: Waypoint[];
  createdAt: string;
}

const DEFAULT_ROUTES: SavedRoute[] = [
  {
    id: 'route-apple-park',
    name: 'Apple Park Perimeter Loop',
    distanceMeters: 2840,
    createdAt: new Date().toLocaleDateString(),
    waypoints: [
      { lat: 37.3349, lng: -122.0090 },
      { lat: 37.3365, lng: -122.0065 },
      { lat: 37.3350, lng: -122.0030 },
      { lat: 37.3325, lng: -122.0040 },
      { lat: 37.3315, lng: -122.0075 },
      { lat: 37.3349, lng: -122.0090 }
    ]
  },
  {
    id: 'route-embarcadero',
    name: 'SF Embarcadero Waterfront',
    distanceMeters: 4120,
    createdAt: new Date().toLocaleDateString(),
    waypoints: [
      { lat: 37.7955, lng: -122.3937 },
      { lat: 37.8010, lng: -122.3975 },
      { lat: 37.8080, lng: -122.4098 },
      { lat: 37.8085, lng: -122.4172 }
    ]
  }
];

export default function App() {
  // Navigation & Location state
  const [currentLoc, setCurrentLoc] = useState<Waypoint>({ lat: 37.3349, lng: -122.0090 });
  const [pin, setPin] = useState<Waypoint | null>(null);
  const [isSpoofing, setIsSpoofing] = useState<boolean>(false);
  const [isRouteActive, setIsRouteActive] = useState<boolean>(false);
  const [activeRouteIndex, setActiveRouteIndex] = useState<number>(0);
  const [activeWaypoints, setActiveWaypoints] = useState<Waypoint[]>([]);

  // Travel speed & mode
  const [travelMode, setTravelMode] = useState<'walk' | 'run' | 'cycle' | 'drive'>('walk');
  const [customSpeed, setCustomSpeed] = useState<number>(4); // km/h
  const [speedUnit, setSpeedUnit] = useState<'kmh' | 'mph' | 'ms'>('kmh');
  const [joystickActive, setJoystickActive] = useState<boolean>(false);

  // Modals & Panels
  const [showSidebar, setShowSidebar] = useState<boolean>(false);
  const [showSettings, setShowSettings] = useState<boolean>(false);
  const [showPlaces, setShowPlaces] = useState<boolean>(false);
  const [showETACalc, setShowETACalc] = useState<boolean>(false);
  const [showBuildInfo, setShowBuildInfo] = useState<boolean>(false);

  // Appearance
  const [themeMode, setThemeMode] = useState<'system' | 'light' | 'dark'>('dark');
  const [copiedCSS, setCopiedCSS] = useState<boolean>(false);

  // Saved Routes & Favorites from localStorage
  const [savedRoutes, setSavedRoutes] = useState<SavedRoute[]>(() => {
    try {
      const stored = localStorage.getItem('locus_saved_routes');
      return stored ? JSON.parse(stored) : DEFAULT_ROUTES;
    } catch {
      return DEFAULT_ROUTES;
    }
  });

  const [routeSearch, setRouteSearch] = useState<string>('');

  // Leaflet references
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<L.Map | null>(null);
  const markerRef = useRef<L.Marker | null>(null);
  const pinMarkerRef = useRef<L.Marker | null>(null);
  const routePolylineRef = useRef<L.Polyline | null>(null);

  // Sync saved routes to localStorage
  useEffect(() => {
    try {
      localStorage.setItem('locus_saved_routes', JSON.stringify(savedRoutes));
    } catch (e) {
      console.error(e);
    }
  }, [savedRoutes]);

  // Sync Theme Mode
  useEffect(() => {
    const root = document.documentElement;
    if (themeMode === 'light') {
      root.classList.add('light');
      root.classList.remove('dark');
    } else {
      root.classList.add('dark');
      root.classList.remove('light');
    }
  }, [themeMode]);

  // Initialize Map
  useEffect(() => {
    if (!mapContainerRef.current || mapRef.current) return;

    const map = L.map(mapContainerRef.current, {
      zoomControl: false,
      attributionControl: false
    }).setView([currentLoc.lat, currentLoc.lng], 16);

    L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
      maxZoom: 19
    }).addTo(map);

    L.control.zoom({ position: 'topright' }).addTo(map);

    // Click handler for dropping teleport pin
    map.on('click', (e: L.LeafletMouseEvent) => {
      const clicked = { lat: e.latlng.lat, lng: e.latlng.lng };
      setPin(clicked);
    });

    mapRef.current = map;

    return () => {
      map.remove();
      mapRef.current = null;
    };
  }, []);

  // Sync current location marker
  useEffect(() => {
    if (!mapRef.current) return;

    const locIcon = L.divIcon({
      className: 'custom-loc-marker',
      html: `
        <div style="
          width: 22px; 
          height: 22px; 
          background: #22E58B; 
          border: 3px solid white; 
          border-radius: 50%; 
          box-shadow: 0 0 12px rgba(34,229,139,0.8);
        "></div>
      `,
      iconSize: [22, 22],
      iconAnchor: [11, 11]
    });

    if (markerRef.current) {
      markerRef.current.setLatLng([currentLoc.lat, currentLoc.lng]);
    } else {
      markerRef.current = L.marker([currentLoc.lat, currentLoc.lng], { icon: locIcon }).addTo(mapRef.current);
    }
  }, [currentLoc]);

  // Sync teleport pin marker
  useEffect(() => {
    if (!mapRef.current) return;

    if (pin) {
      const pinIcon = L.divIcon({
        className: 'custom-pin-marker',
        html: `
          <div style="
            width: 24px; 
            height: 24px; 
            background: #EF4444; 
            border: 3px solid white; 
            border-radius: 50%; 
            box-shadow: 0 0 14px rgba(239,68,68,0.9);
          "></div>
        `,
        iconSize: [24, 24],
        iconAnchor: [12, 12]
      });

      if (pinMarkerRef.current) {
        pinMarkerRef.current.setLatLng([pin.lat, pin.lng]);
      } else {
        pinMarkerRef.current = L.marker([pin.lat, pin.lng], { icon: pinIcon }).addTo(mapRef.current);
      }
    } else if (pinMarkerRef.current) {
      pinMarkerRef.current.remove();
      pinMarkerRef.current = null;
    }
  }, [pin]);

  // Sync active route polyline
  useEffect(() => {
    if (!mapRef.current) return;

    if (activeWaypoints.length > 0) {
      const latlngs = activeWaypoints.map(w => [w.lat, w.lng] as [number, number]);
      if (routePolylineRef.current) {
        routePolylineRef.current.setLatLngs(latlngs);
      } else {
        routePolylineRef.current = L.polyline(latlngs, {
          color: '#22E58B',
          weight: 5,
          opacity: 0.85,
          dashArray: '8, 8'
        }).addTo(mapRef.current);
      }
    } else if (routePolylineRef.current) {
      routePolylineRef.current.remove();
      routePolylineRef.current = null;
    }
  }, [activeWaypoints]);

  // Route playback simulation loop
  useEffect(() => {
    if (!isRouteActive || activeWaypoints.length < 2) return;

    const interval = setInterval(() => {
      setActiveRouteIndex(prev => {
        const next = prev + 1;
        if (next >= activeWaypoints.length) {
          setIsRouteActive(false);
          return 0;
        }
        setCurrentLoc(activeWaypoints[next]);
        return next;
      });
    }, 1000);

    return () => clearInterval(interval);
  }, [isRouteActive, activeWaypoints]);

  // Actions
  const handleTeleport = () => {
    if (!pin) return;
    setCurrentLoc(pin);
    setIsSpoofing(true);
    setPin(null);
  };

  const handleStopSpoofing = () => {
    setIsSpoofing(false);
    setIsRouteActive(false);
  };

  const handleLoadRoute = (route: SavedRoute) => {
    setActiveWaypoints(route.waypoints);
    setActiveRouteIndex(0);
    setCurrentLoc(route.waypoints[0]);
    setIsSpoofing(true);
    setIsRouteActive(true);
    setShowSidebar(false);
    if (mapRef.current) {
      mapRef.current.flyTo([route.waypoints[0].lat, route.waypoints[0].lng], 16);
    }
  };

  const handleDeleteRoute = (id: string) => {
    setSavedRoutes(prev => prev.filter(r => r.id !== id));
  };

  const handleExportGPX = (route: SavedRoute) => {
    const gpxData = `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Locus">
  <trk>
    <name>${route.name}</name>
    <trkseg>
${route.waypoints.map(w => `      <trkpt lat="${w.lat}" lon="${w.lng}"></trkpt>`).join('\n')}
    </trkseg>
  </trk>
</gpx>`;
    const blob = new Blob([gpxData], { type: 'application/gpx+xml' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${route.name.replace(/\s+/g, '_')}.gpx`;
    a.click();
    URL.revokeObjectURL(url);
  };

  // Joystick move delta
  const handleJoystickMove = (dx: number, dy: number) => {
    const speedFactor = customSpeed / 3600 / 111.32; // rough lat/deg per sec
    setCurrentLoc(prev => ({
      lat: prev.lat + dy * speedFactor * 0.5,
      lng: prev.lng + dx * speedFactor * 0.5
    }));
    setIsSpoofing(true);
  };

  // ETA Calculation
  const selectedDistance = activeWaypoints.length > 1 ? 2840 : 1500;
  const effectiveSpeedKmh = speedUnit === 'mph' ? customSpeed * 1.60934 : speedUnit === 'ms' ? customSpeed * 3.6 : customSpeed;
  const durationSeconds = effectiveSpeedKmh > 0 ? (selectedDistance / 1000 / effectiveSpeedKmh) * 3600 : 0;
  const arrivalDate = new Date(Date.now() + durationSeconds * 1000);

  const filteredRoutes = savedRoutes.filter(r => 
    r.name.toLowerCase().includes(routeSearch.toLowerCase())
  );

  return (
    <div className="relative w-screen h-screen overflow-hidden bg-black select-none">
      {/* Leaflet Map Canvas */}
      <div ref={mapContainerRef} className="w-full h-full z-0" />

      {/* Top Status Bar */}
      <div className="absolute top-4 left-4 right-4 z-20 flex justify-center pointer-events-none">
        <div className="locus-glass pointer-events-auto rounded-full px-5 py-2.5 flex items-center gap-3 text-sm shadow-xl">
          <div 
            className={`w-2.5 h-2.5 rounded-full ${
              isRouteActive ? 'bg-accent animate-pulse' : isSpoofing ? 'bg-accent' : 'bg-gray-400'
            }`} 
          />
          <span className="font-semibold">
            {isRouteActive 
              ? `Route Active • Step ${activeRouteIndex + 1}/${activeWaypoints.length}` 
              : isSpoofing 
              ? 'Spoofing Active' 
              : 'Standby'}
          </span>
          <span className="text-xs font-mono text-gray-400">
            {currentLoc.lat.toFixed(4)}, {currentLoc.lng.toFixed(4)}
          </span>
        </div>
      </div>

      {/* Floating Quick Action Map Tools */}
      <div className="absolute top-20 right-4 z-20 flex flex-col gap-2">
        <button 
          onClick={() => setShowETACalc(true)}
          className="locus-glass w-11 h-11 rounded-full flex items-center justify-center hover:scale-105 transition"
          title="Route ETA Calculator"
        >
          <Clock className="w-5 h-5 text-accent" />
        </button>
        <button 
          onClick={() => setShowBuildInfo(true)}
          className="locus-glass w-11 h-11 rounded-full flex items-center justify-center hover:scale-105 transition"
          title="IPA & Build Pipeline"
        >
          <FolderGit2 className="w-5 h-5 text-accent-secondary" />
        </button>
      </div>

      {/* Joystick Pad Overlay */}
      {joystickActive && (
        <div className="absolute bottom-28 right-6 z-30">
          <div className="locus-glass rounded-full w-36 h-36 relative flex items-center justify-center border-2 border-accent/40 shadow-2xl">
            <button 
              className="absolute top-2 text-xs font-bold text-gray-300 hover:text-white"
              onClick={() => handleJoystickMove(0, 1)}
            >▲</button>
            <button 
              className="absolute bottom-2 text-xs font-bold text-gray-300 hover:text-white"
              onClick={() => handleJoystickMove(0, -1)}
            >▼</button>
            <button 
              className="absolute left-2 text-xs font-bold text-gray-300 hover:text-white"
              onClick={() => handleJoystickMove(-1, 0)}
            >◀</button>
            <button 
              className="absolute right-2 text-xs font-bold text-gray-300 hover:text-white"
              onClick={() => handleJoystickMove(1, 0)}
            >▶</button>
            <div className="w-12 h-12 bg-accent rounded-full flex items-center justify-center shadow-lg text-black font-bold">
              JOY
            </div>
          </div>
        </div>
      )}

      {/* Bottom Floating Control Tray */}
      <div className="absolute bottom-4 left-4 right-4 z-20 flex justify-center">
        <div className="locus-glass rounded-3xl p-3 w-full max-w-md shadow-2xl flex flex-col gap-3">
          {/* Mode & Speed Chips */}
          <div className="flex items-center justify-between gap-1">
            <div className="flex items-center gap-1 bg-black/30 p-1 rounded-full">
              {(['walk', 'run', 'cycle', 'drive'] as const).map(mode => (
                <button
                  key={mode}
                  onClick={() => {
                    setTravelMode(mode);
                    setCustomSpeed(mode === 'walk' ? 4 : mode === 'run' ? 12 : mode === 'cycle' ? 25 : 65);
                  }}
                  className={`px-3 py-1.5 rounded-full text-xs font-semibold capitalize transition ${
                    travelMode === mode ? 'bg-accent text-black font-bold' : 'text-gray-300 hover:text-white'
                  }`}
                >
                  {mode}
                </button>
              ))}
            </div>

            <div className="flex items-center gap-1.5 px-3 py-1 bg-black/40 rounded-full text-xs font-mono">
              <Gauge className="w-3.5 h-3.5 text-accent" />
              <input 
                type="number" 
                value={customSpeed} 
                onChange={e => setCustomSpeed(Math.max(1, Number(e.target.value)))}
                className="w-10 bg-transparent text-right outline-none font-bold text-white" 
              />
              <span className="text-gray-400">{speedUnit}</span>
            </div>
          </div>

          {/* Action Row */}
          <div className="flex items-center justify-between gap-2">
            <button
              onClick={() => setShowSidebar(true)}
              className="w-11 h-11 rounded-full locus-glass flex items-center justify-center text-gray-300 hover:text-white hover:border-accent transition"
              title="Saved GPX Routes"
            >
              <Layers className="w-5 h-5" />
            </button>

            <button
              onClick={() => setShowSettings(true)}
              className="w-11 h-11 rounded-full locus-glass flex items-center justify-center text-gray-300 hover:text-white hover:border-accent transition"
              title="Settings & Appearance"
            >
              <SettingsIcon className="w-5 h-5" />
            </button>

            <button
              onClick={() => setJoystickActive(!joystickActive)}
              className={`px-4 py-2.5 rounded-full text-xs font-bold transition flex items-center gap-1.5 ${
                joystickActive ? 'bg-accent-secondary text-black' : 'locus-glass text-gray-300 hover:text-white'
              }`}
            >
              <Compass className="w-4 h-4" />
              {joystickActive ? 'Joy ON' : 'Joystick'}
            </button>

            {isSpoofing || isRouteActive ? (
              <button
                onClick={handleStopSpoofing}
                className="flex-1 py-2.5 rounded-full bg-danger text-white text-xs font-bold flex items-center justify-center gap-1.5 hover:bg-red-600 transition"
              >
                <Square className="w-4 h-4 fill-current" />
                Stop
              </button>
            ) : (
              <button
                onClick={handleTeleport}
                disabled={!pin}
                className={`flex-1 py-2.5 rounded-full text-xs font-bold flex items-center justify-center gap-1.5 transition ${
                  pin ? 'bg-accent text-black hover:opacity-90 shadow-lg' : 'bg-gray-700 text-gray-400 cursor-not-allowed'
                }`}
              >
                <MapPin className="w-4 h-4" />
                {pin ? 'Teleport' : 'Tap Map'}
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Routes Sidebar Modal */}
      {showSidebar && (
        <div className="fixed inset-0 z-50 flex">
          <div 
            className="fixed inset-0 bg-black/60 backdrop-blur-sm"
            onClick={() => setShowSidebar(false)}
          />
          <div className="relative w-80 max-w-[85vw] h-full locus-glass border-r border-white/10 flex flex-col z-10 p-4">
            <div className="flex items-center justify-between pb-3 border-b border-white/10">
              <div className="flex items-center gap-2">
                <Navigation className="w-5 h-5 text-accent" />
                <h2 className="font-bold text-base">Saved GPX Routes</h2>
              </div>
              <button 
                onClick={() => setShowSidebar(false)}
                className="p-1 rounded-full hover:bg-white/10"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="my-3 flex items-center gap-2 bg-black/40 px-3 py-1.5 rounded-xl border border-white/10">
              <Search className="w-4 h-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search routes…"
                value={routeSearch}
                onChange={e => setRouteSearch(e.target.value)}
                className="w-full bg-transparent text-xs text-white placeholder-gray-400 outline-none"
              />
            </div>

            <div className="flex-1 overflow-y-auto space-y-2.5 pr-1">
              {filteredRoutes.map(route => (
                <div key={route.id} className="p-3 rounded-2xl bg-white/5 border border-white/10 hover:border-accent/40 transition">
                  <div className="font-semibold text-sm line-clamp-1">{route.name}</div>
                  <div className="text-xs text-gray-400 mt-1 flex items-center gap-2 font-mono">
                    <span className="text-accent">{(route.distanceMeters / 1000).toFixed(2)} km</span>
                    <span>•</span>
                    <span>{route.waypoints.length} pts</span>
                  </div>
                  <div className="flex items-center justify-end gap-2 mt-2 pt-2 border-t border-white/5">
                    <button
                      onClick={() => handleExportGPX(route)}
                      className="p-1.5 rounded-lg text-gray-400 hover:text-white hover:bg-white/10"
                      title="Export GPX"
                    >
                      <Download className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => handleDeleteRoute(route.id)}
                      className="p-1.5 rounded-lg text-red-400 hover:text-red-300 hover:bg-white/10"
                      title="Delete Route"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => handleLoadRoute(route)}
                      className="px-3 py-1 rounded-full bg-accent text-black font-bold text-xs hover:opacity-90"
                    >
                      Load
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Route ETA Calculator Modal */}
      {showETACalc && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div className="fixed inset-0 bg-black/60 backdrop-blur-sm" onClick={() => setShowETACalc(false)} />
          <div className="relative w-full max-w-sm locus-glass rounded-3xl p-5 border border-white/10 z-10 flex flex-col gap-4">
            <div className="flex items-center justify-between pb-2 border-b border-white/10">
              <div className="flex items-center gap-2">
                <Clock className="w-5 h-5 text-accent" />
                <h3 className="font-bold text-base">Route ETA Calculator</h3>
              </div>
              <button onClick={() => setShowETACalc(false)} className="p-1 rounded-full hover:bg-white/10">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="grid grid-cols-2 gap-3 text-center">
              <div className="p-3 bg-white/5 rounded-2xl">
                <div className="text-xs text-gray-400">Duration</div>
                <div className="text-lg font-bold text-accent font-mono mt-0.5">
                  {Math.floor(durationSeconds / 60)}m {Math.floor(durationSeconds % 60)}s
                </div>
              </div>
              <div className="p-3 bg-white/5 rounded-2xl">
                <div className="text-xs text-gray-400">Arrival Time</div>
                <div className="text-lg font-bold text-white font-mono mt-0.5">
                  {arrivalDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </div>
              </div>
            </div>

            <div className="flex items-center justify-between bg-black/40 px-3 py-2 rounded-xl text-xs">
              <span className="text-gray-400">Speed Unit</span>
              <div className="flex gap-1">
                {(['kmh', 'mph', 'ms'] as const).map(u => (
                  <button
                    key={u}
                    onClick={() => setSpeedUnit(u)}
                    className={`px-2 py-0.5 rounded font-mono font-bold ${
                      speedUnit === u ? 'bg-accent text-black' : 'text-gray-400 hover:text-white'
                    }`}
                  >
                    {u}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Settings & Appearance Modal */}
      {showSettings && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div className="fixed inset-0 bg-black/60 backdrop-blur-sm" onClick={() => setShowSettings(false)} />
          <div className="relative w-full max-w-sm locus-glass rounded-3xl p-5 border border-white/10 z-10 flex flex-col gap-4">
            <div className="flex items-center justify-between pb-2 border-b border-white/10">
              <div className="flex items-center gap-2">
                <SettingsIcon className="w-5 h-5 text-accent" />
                <h3 className="font-bold text-base">Appearance & Theme</h3>
              </div>
              <button onClick={() => setShowSettings(false)} className="p-1 rounded-full hover:bg-white/10">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div>
              <label className="text-xs text-gray-400 font-semibold mb-2 block">Interface Mode</label>
              <div className="grid grid-cols-3 gap-2">
                {[
                  { mode: 'system', icon: Laptop, label: 'System' },
                  { mode: 'light', icon: Sun, label: 'Light' },
                  { mode: 'dark', icon: Moon, label: 'Dark' }
                ].map(({ mode, icon: Icon, label }) => (
                  <button
                    key={mode}
                    onClick={() => setThemeMode(mode as any)}
                    className={`p-2.5 rounded-2xl flex flex-col items-center gap-1 text-xs font-semibold transition ${
                      themeMode === mode ? 'bg-accent text-black font-bold' : 'bg-white/5 text-gray-300 hover:bg-white/10'
                    }`}
                  >
                    <Icon className="w-4 h-4" />
                    {label}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <div className="flex items-center justify-between text-xs text-gray-400 mb-1.5 font-semibold">
                <span>CSS Variables</span>
                <button
                  onClick={() => {
                    navigator.clipboard.writeText(`:root {\n  --accent: #22E58B;\n  --bg-primary: #0a0e14;\n}`);
                    setCopiedCSS(true);
                    setTimeout(() => setCopiedCSS(false), 2000);
                  }}
                  className="flex items-center gap-1 text-accent hover:underline"
                >
                  {copiedCSS ? <Check className="w-3 h-3" /> : <Copy className="w-3 h-3" />}
                  {copiedCSS ? 'Copied' : 'Copy'}
                </button>
              </div>
              <div className="p-3 bg-black/50 rounded-2xl text-[11px] font-mono text-gray-300 space-y-1">
                <div><span className="text-accent">--accent:</span> #22E58B</div>
                <div><span className="text-accent-secondary">--accent-sec:</span> #60A5FA</div>
                <div><span className="text-gray-400">--bg-primary:</span> {themeMode === 'light' ? '#f8fafc' : '#0a0e14'}</div>
                <div><span className="text-gray-400">--panel-bg:</span> rgba(18, 24, 32, 0.85)</div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Build & IPA Pipeline Info Modal */}
      {showBuildInfo && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div className="fixed inset-0 bg-black/60 backdrop-blur-sm" onClick={() => setShowBuildInfo(false)} />
          <div className="relative w-full max-w-md locus-glass rounded-3xl p-5 border border-white/10 z-10 flex flex-col gap-4">
            <div className="flex items-center justify-between pb-2 border-b border-white/10">
              <div className="flex items-center gap-2">
                <FolderGit2 className="w-5 h-5 text-accent-secondary" />
                <h3 className="font-bold text-base">iOS IPA & Build Pipeline</h3>
              </div>
              <button onClick={() => setShowBuildInfo(false)} className="p-1 rounded-full hover:bg-white/10">
                <X className="w-5 h-5" />
              </button>
            </div>

            <p className="text-xs text-gray-300 leading-relaxed">
              The native iOS application with device-level DVT location spoofing is configured for automated unsigned IPA builds.
            </p>

            <div className="bg-black/50 p-3 rounded-2xl text-xs space-y-2 font-mono text-gray-300">
              <div className="text-accent font-semibold">GitHub Actions Workflow:</div>
              <div className="text-[11px] text-gray-400">.github/workflows/build.yml</div>
              <div className="border-t border-white/10 pt-2 text-[11px]">
                Target: <span className="text-white">LocusPlus-unsigned.ipa</span><br/>
                Runner: <span className="text-white">macos-15 (Apple Silicon)</span><br/>
                Target SDK: <span className="text-white">iOS 18.0+</span>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
