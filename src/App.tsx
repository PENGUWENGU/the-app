import React, { useState, useEffect, useRef } from 'react';
import {
  MapPin,
  Navigation,
  Play,
  Square,
  Compass,
  Settings,
  Star,
  Bookmark,
  ChevronRight,
  Layers,
  Search,
  Crosshair,
  Sliders,
  Radio,
  Share2,
  X,
  Plus,
  RefreshCw,
  FolderOpen,
  Route,
  Zap,
  Gauge,
  Activity,
  ArrowUpRight,
  ShieldCheck,
  Check
} from 'lucide-react';

interface Coordinate {
  lat: number;
  lng: number;
}

const PRESET_PLACES = [
  { name: 'Apple Park (Cupertino)', lat: 37.3349, lng: -122.0090, desc: '1 Apple Park Way, Cupertino, CA' },
  { name: 'Tokyo Tower', lat: 35.6586, lng: 139.7454, desc: 'Minato City, Tokyo, Japan' },
  { name: 'Central Park (NYC)', lat: 40.785091, lng: -73.968285, desc: 'New York, NY 10024' },
  { name: 'Sydney Opera House', lat: -33.8568, lng: 151.2153, desc: 'Bennelong Point, Sydney NSW' },
  { name: 'Eiffel Tower', lat: 48.8584, lng: 2.2945, desc: 'Champ de Mars, Paris, France' }
];

export default function App() {
  // Map State
  const [pin, setPin] = useState<Coordinate>({ lat: 37.3349, lng: -122.0090 });
  const [simulated, setSimulated] = useState<Coordinate | null>(null);
  const [isSpoofing, setIsSpoofing] = useState(false);
  const [speedMPS, setSpeedMPS] = useState(1.4); // Walk (5 km/h)
  const [activeTab, setActiveTab] = useState<'map' | 'routes' | 'places' | 'settings'>('map');
  const [mapStyle, setMapStyle] = useState<'standard' | 'hybrid' | 'imagery'>('standard');
  const [theme, setTheme] = useState<'mint' | 'cyberpunk' | 'electric'>('mint');

  // Route State
  const [routeCoords, setRouteCoords] = useState<Coordinate[]>([]);
  const [isRouteActive, setIsRouteActive] = useState(false);
  const [routeProgress, setRouteProgress] = useState(0);
  const [showRouteSheet, setShowRouteSheet] = useState(false);
  const [showSettingsSheet, setShowSettingsSheet] = useState(false);
  const [showPlacesSheet, setShowPlacesSheet] = useState(false);
  const [showSidebar, setShowSidebar] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [savedPlaces, setSavedPlaces] = useState(PRESET_PLACES);

  // Joystick State
  const [joystickVector, setJoystickVector] = useState<{ x: number; y: number }>({ x: 0, y: 0 });
  const [isDraggingJoystick, setIsDraggingJoystick] = useState(false);
  const joystickCenterRef = useRef<HTMLDivElement>(null);

  // Spoof Simulation Loop
  useEffect(() => {
    if (!isSpoofing) return;

    const interval = setInterval(() => {
      // Joystick movement
      if (joystickVector.x !== 0 || joystickVector.y !== 0) {
        setSimulated(prev => {
          const curr = prev || pin;
          const latStep = (joystickVector.y * 0.00002 * (speedMPS / 1.4));
          const lngStep = (joystickVector.x * 0.000025 * (speedMPS / 1.4));
          return {
            lat: Number((curr.lat + latStep).toFixed(6)),
            lng: Number((curr.lng + lngStep).toFixed(6))
          };
        });
      }

      // Route playback
      if (isRouteActive && routeCoords.length > 1) {
        setRouteProgress(prev => {
          const next = prev + 0.008;
          if (next >= 1) {
            setIsRouteActive(false);
            return 0;
          }
          const index = Math.floor(next * (routeCoords.length - 1));
          setSimulated(routeCoords[index]);
          return next;
        });
      }
    }, 100);

    return () => clearInterval(interval);
  }, [isSpoofing, joystickVector, isRouteActive, routeCoords, speedMPS, pin]);

  // Handle Map Click to Drop Pin
  const handleMapClick = (e: React.MouseEvent<HTMLDivElement>) => {
    if (isRouteActive) return;
    const rect = e.currentTarget.getBoundingClientRect();
    const x = (e.clientX - rect.left) / rect.width;
    const y = (e.clientY - rect.top) / rect.height;

    // Approximate lat/lng around current view center
    const center = simulated || pin;
    const newLat = center.lat + (0.5 - y) * 0.012;
    const newLng = center.lng + (x - 0.5) * 0.016;

    setPin({ lat: Number(newLat.toFixed(6)), lng: Number(newLng.toFixed(6)) });
  };

  // Start Instant Spoof
  const handleStartSpoof = () => {
    setSimulated(pin);
    setIsSpoofing(true);
  };

  const handleStopSpoof = () => {
    setIsSpoofing(false);
    setIsRouteActive(false);
  };

  // Build Road Route
  const handleBuildRoute = () => {
    const start = simulated || pin;
    const dest = { lat: start.lat + 0.0045, lng: start.lng + 0.0065 };
    const intermediate1 = { lat: start.lat + 0.0018, lng: start.lng + 0.0032 };
    const intermediate2 = { lat: start.lat + 0.0035, lng: start.lng + 0.0048 };
    
    setRouteCoords([start, intermediate1, intermediate2, dest]);
    setShowRouteSheet(false);
    setIsRouteActive(true);
    setIsSpoofing(true);
    setRouteProgress(0);
  };

  // Joystick pointer events
  const handleJoystickMove = (clientX: number, clientY: number) => {
    if (!joystickCenterRef.current) return;
    const rect = joystickCenterRef.current.getBoundingClientRect();
    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;

    const dx = clientX - cx;
    const dy = clientY - cy;
    const dist = Math.hypot(dx, dy);
    const maxRadius = 38;

    const clampedDist = Math.min(dist, maxRadius);
    const angle = Math.atan2(dy, dx);

    const nx = (Math.cos(angle) * clampedDist) / maxRadius;
    const ny = -(Math.sin(angle) * clampedDist) / maxRadius;

    setJoystickVector({ x: nx, y: ny });
  };

  const currentCoords = simulated || pin;

  return (
    <div className="flex h-screen w-full select-none bg-[#090D14] text-white font-sans overflow-hidden">
      {/* Sidebar Navigation */}
      {showSidebar && (
        <div className="w-80 h-full bg-[#111622]/95 backdrop-blur-2xl border-r border-white/10 flex flex-col z-30 animate-in slide-in-from-left duration-200">
          <div className="p-4 border-b border-white/10 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-xl bg-gradient-to-tr from-cyan-500 to-teal-400 flex items-center justify-center font-bold text-black text-sm">
                L
              </div>
              <span className="font-bold tracking-tight text-lg">Locus iOS</span>
            </div>
            <button 
              onClick={() => setShowSidebar(false)}
              className="p-1.5 rounded-full hover:bg-white/10 text-white/70"
            >
              <X size={18} />
            </button>
          </div>

          <div className="p-3 overflow-y-auto flex-1 space-y-4">
            <div>
              <div className="text-[11px] font-semibold uppercase tracking-wider text-white/40 px-3 mb-2">Saved Routes</div>
              <div className="space-y-1">
                <div 
                  onClick={handleBuildRoute}
                  className="p-3 rounded-xl bg-white/5 hover:bg-white/10 cursor-pointer border border-white/5 flex items-center justify-between"
                >
                  <div className="flex items-center gap-3">
                    <Route size={16} className="text-cyan-400" />
                    <div>
                      <div className="font-medium text-sm">Cupertino Loop</div>
                      <div className="text-xs text-white/50">1.8 km • 4 waypoints</div>
                    </div>
                  </div>
                  <ChevronRight size={14} className="text-white/40" />
                </div>
              </div>
            </div>

            <div>
              <div className="text-[11px] font-semibold uppercase tracking-wider text-white/40 px-3 mb-2">Device Status</div>
              <div className="p-3 rounded-xl bg-white/5 border border-white/5 space-y-2 text-xs">
                <div className="flex justify-between">
                  <span className="text-white/60">Tunnel</span>
                  <span className="text-emerald-400 font-medium">LocalDevVPN (Connected)</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-white/60">Pairing</span>
                  <span className="text-cyan-400 font-medium">CoreDevice (Paired)</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-white/60">Keep-Alive</span>
                  <span className="text-emerald-400 font-medium">Silent Audio Running</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Main Map Canvas Area */}
      <div className="relative flex-1 h-full flex flex-col">
        {/* Top Header Floating Island */}
        <div className="absolute top-4 inset-x-4 z-20 flex items-center justify-between pointer-events-none">
          {/* Top Left Menu / Status Pill */}
          <div className="flex items-center gap-2 pointer-events-auto">
            <button
              onClick={() => setShowSidebar(!showSidebar)}
              className="h-10 px-3 rounded-full bg-[#161B26]/85 backdrop-blur-xl border border-white/10 flex items-center gap-2 shadow-2xl hover:bg-white/10 active:scale-95 transition"
            >
              <div className="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-pulse" />
              <span className="text-xs font-semibold tracking-wide">
                {isRouteActive ? 'Route Simulating' : isSpoofing ? 'Spoof Active' : 'Not Spoofing'}
              </span>
            </button>
          </div>

          {/* Top Search Bar */}
          <div className="flex-1 max-w-sm mx-3 pointer-events-auto">
            <div className="relative flex items-center">
              <Search className="absolute left-3 text-white/40" size={15} />
              <input
                type="text"
                placeholder="Search places or coordinates..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full h-10 pl-9 pr-4 rounded-full bg-[#161B26]/85 backdrop-blur-xl border border-white/10 text-xs text-white placeholder-white/40 focus:outline-none focus:border-cyan-400/50 shadow-2xl"
              />
            </div>
          </div>

          {/* Top Right Quick Actions */}
          <div className="flex items-center gap-2 pointer-events-auto">
            <button
              onClick={() => setShowPlacesSheet(true)}
              className="w-10 h-10 rounded-full bg-[#161B26]/85 backdrop-blur-xl border border-white/10 flex items-center justify-center hover:bg-white/10 active:scale-95 transition shadow-2xl text-amber-300"
            >
              <Star size={16} />
            </button>
            <button
              onClick={() => setShowSettingsSheet(true)}
              className="w-10 h-10 rounded-full bg-[#161B26]/85 backdrop-blur-xl border border-white/10 flex items-center justify-center hover:bg-white/10 active:scale-95 transition shadow-2xl text-white/80"
            >
              <Settings size={16} />
            </button>
          </div>
        </div>

        {/* Map View Area */}
        <div 
          onClick={handleMapClick}
          className="relative w-full h-full bg-[#0E131E] cursor-crosshair overflow-hidden"
          style={{
            backgroundImage: `
              radial-gradient(circle at 50% 50%, rgba(34, 45, 66, 0.4) 0%, rgba(10, 14, 22, 1) 100%),
              linear-gradient(rgba(255,255,255,0.03) 1px, transparent 1px),
              linear-gradient(90deg, rgba(255,255,255,0.03) 1px, transparent 1px)
            `,
            backgroundSize: '100% 100%, 40px 40px, 40px 40px'
          }}
        >
          {/* Map Vector Roads / Grid Mock */}
          <div className="absolute inset-0 opacity-20 pointer-events-none">
            <svg className="w-full h-full">
              <path d="M 0 300 Q 400 250 800 500 T 1600 400" stroke="#59C7B8" strokeWidth="4" fill="none" />
              <path d="M 200 0 Q 300 400 400 800 T 600 1200" stroke="#38BDF8" strokeWidth="3" fill="none" />
              <path d="M 600 100 L 900 800" stroke="#A855F7" strokeWidth="2" strokeDasharray="6 4" fill="none" />
            </svg>
          </div>

          {/* Active Route Polyline */}
          {routeCoords.length > 1 && (
            <svg className="absolute inset-0 w-full h-full pointer-events-none z-10">
              <polyline
                points="300,280 420,340 540,310 650,420"
                fill="none"
                stroke="#06D6A0"
                strokeWidth="6"
                strokeLinecap="round"
                strokeLinejoin="round"
                className="drop-shadow-[0_0_12px_rgba(6,214,160,0.8)]"
              />
            </svg>
          )}

          {/* Dropped Target Pin */}
          <div 
            className="absolute -translate-x-1/2 -translate-y-full transition-all duration-300 z-10 pointer-events-none"
            style={{ left: '50%', top: '50%' }}
          >
            <div className="flex flex-col items-center group">
              <div className="px-2.5 py-1 rounded-lg bg-black/80 backdrop-blur-md border border-white/20 text-[10px] font-mono text-cyan-300 mb-1 shadow-xl">
                {pin.lat.toFixed(5)}, {pin.lng.toFixed(5)}
              </div>
              <div className="relative">
                <MapPin className="text-red-500 fill-red-500 drop-shadow-[0_4px_12px_rgba(239,68,68,0.8)]" size={36} />
              </div>
            </div>
          </div>

          {/* Simulated Spoof Dot with Pulse Wave */}
          {isSpoofing && (
            <div 
              className="absolute -translate-x-1/2 -translate-y-1/2 transition-all duration-150 z-20 pointer-events-none"
              style={{ left: '52%', top: '48%' }}
            >
              <div className="relative flex items-center justify-center">
                <div className="absolute w-12 h-12 rounded-full bg-cyan-400/25 animate-ping" />
                <div className="absolute w-8 h-8 rounded-full bg-cyan-400/40" />
                <div className="w-4 h-4 rounded-full bg-cyan-400 border-2 border-white shadow-[0_0_15px_#22d3ee]" />
              </div>
            </div>
          )}
        </div>

        {/* Floating Bottom Left Joystick */}
        <div className="absolute left-6 bottom-24 z-20 select-none">
          <div className="flex flex-col items-center gap-2">
            {/* Speed Selector Buttons */}
            <div className="flex items-center gap-1 p-1 rounded-full bg-[#161B26]/85 backdrop-blur-xl border border-white/10 shadow-2xl">
              {[
                { label: 'Walk', speed: 1.4 },
                { label: 'Run', speed: 3.3 },
                { label: 'Cycle', speed: 6.9 },
                { label: 'Drive', speed: 16.6 }
              ].map(item => (
                <button
                  key={item.label}
                  onClick={() => setSpeedMPS(item.speed)}
                  className={`px-2.5 py-1 rounded-full text-[10px] font-semibold transition ${
                    speedMPS === item.speed
                      ? 'bg-cyan-500 text-black shadow-md'
                      : 'text-white/60 hover:text-white'
                  }`}
                >
                  {item.label}
                </button>
              ))}
            </div>

            {/* Joystick Dial */}
            <div
              ref={joystickCenterRef}
              onMouseDown={() => setIsDraggingJoystick(true)}
              onMouseUp={() => {
                setIsDraggingJoystick(false);
                setJoystickVector({ x: 0, y: 0 });
              }}
              onMouseMove={(e) => {
                if (isDraggingJoystick) handleJoystickMove(e.clientX, e.clientY);
              }}
              className="relative w-28 h-28 rounded-full bg-[#161B26]/90 backdrop-blur-2xl border border-white/15 shadow-2xl flex items-center justify-center cursor-grab active:cursor-grabbing"
            >
              {/* Direction crosshairs */}
              <div className="absolute w-full h-[1px] bg-white/10" />
              <div className="absolute h-full w-[1px] bg-white/10" />

              {/* Center Thumb */}
              <div
                className="w-11 h-11 rounded-full bg-gradient-to-tr from-cyan-500 to-teal-400 border-2 border-white/80 shadow-[0_0_15px_rgba(6,214,160,0.6)] flex items-center justify-center transition-transform"
                style={{
                  transform: `translate(${joystickVector.x * 32}px, ${-joystickVector.y * 32}px)`
                }}
              >
                <Compass size={16} className="text-black" />
              </div>
            </div>
          </div>
        </div>

        {/* Floating Bottom Control Bar (Liquid Glass Pill) */}
        <div className="absolute bottom-6 inset-x-6 z-20 flex justify-center pointer-events-none">
          <div className="pointer-events-auto h-16 px-4 rounded-3xl bg-[#161B26]/85 backdrop-blur-2xl border border-white/15 shadow-[0_12px_40px_rgba(0,0,0,0.6)] flex items-center gap-3">
            {/* Primary Spoof Button */}
            {!isSpoofing ? (
              <button
                onClick={handleStartSpoof}
                className="h-11 px-5 rounded-2xl bg-gradient-to-r from-cyan-500 via-teal-400 to-emerald-400 text-black font-bold text-xs flex items-center gap-2 shadow-lg shadow-cyan-500/20 active:scale-95 transition"
              >
                <Zap size={16} className="fill-black" />
                <span>Spoof Location</span>
              </button>
            ) : (
              <button
                onClick={handleStopSpoof}
                className="h-11 px-5 rounded-2xl bg-red-500/20 border border-red-500/40 text-red-400 font-bold text-xs flex items-center gap-2 shadow-lg active:scale-95 transition"
              >
                <Square size={14} className="fill-red-400" />
                <span>Stop Spoofing</span>
              </button>
            )}

            <div className="w-[1px] h-6 bg-white/15" />

            {/* Route Planner Button */}
            <button
              onClick={() => setShowRouteSheet(true)}
              className="h-11 px-3.5 rounded-2xl hover:bg-white/10 active:scale-95 transition flex items-center gap-2 text-white/80 text-xs font-medium"
            >
              <Route size={16} className="text-cyan-400" />
              <span>Routes</span>
            </button>

            {/* Center Recenter Button */}
            <button
              onClick={() => setPin({ lat: 37.3349, lng: -122.0090 })}
              className="w-11 h-11 rounded-2xl hover:bg-white/10 active:scale-95 transition flex items-center justify-center text-white/80"
            >
              <Crosshair size={18} />
            </button>
          </div>
        </div>
      </div>

      {/* Route Planner Sheet Modal */}
      {showRouteSheet && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-end md:items-center justify-center p-0 md:p-6">
          <div className="w-full max-w-lg bg-[#141A26] rounded-t-3xl md:rounded-3xl border border-white/15 p-6 space-y-5 shadow-2xl">
            <div className="flex items-center justify-between border-b border-white/10 pb-3">
              <div className="flex items-center gap-2">
                <Route className="text-cyan-400" size={20} />
                <h3 className="font-bold text-base">Route Planner & GPX</h3>
              </div>
              <button onClick={() => setShowRouteSheet(false)} className="p-1.5 rounded-full hover:bg-white/10">
                <X size={18} />
              </button>
            </div>

            <div className="space-y-3">
              <div className="p-3.5 rounded-2xl bg-white/5 border border-white/10 space-y-2">
                <div className="text-xs text-white/50">Start Point</div>
                <div className="font-mono text-xs">{currentCoords.lat.toFixed(5)}, {currentCoords.lng.toFixed(5)}</div>
              </div>

              <div className="p-3.5 rounded-2xl bg-white/5 border border-white/10 space-y-2">
                <div className="text-xs text-white/50">Destination (Target Pin)</div>
                <div className="font-mono text-xs">{pin.lat.toFixed(5)}, {pin.lng.toFixed(5)}</div>
              </div>
            </div>

            <div className="flex gap-3 pt-2">
              <button
                onClick={handleBuildRoute}
                className="flex-1 h-12 rounded-2xl bg-gradient-to-r from-cyan-500 to-teal-400 text-black font-bold text-sm flex items-center justify-center gap-2 shadow-lg active:scale-95 transition"
              >
                <Play size={16} className="fill-black" />
                <span>Build Road Route & Play</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Saved Places Sheet Modal */}
      {showPlacesSheet && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-end md:items-center justify-center p-0 md:p-6">
          <div className="w-full max-w-lg bg-[#141A26] rounded-t-3xl md:rounded-3xl border border-white/15 p-6 space-y-4 shadow-2xl max-h-[80vh] flex flex-col">
            <div className="flex items-center justify-between border-b border-white/10 pb-3">
              <div className="flex items-center gap-2">
                <Star className="text-amber-400" size={20} />
                <h3 className="font-bold text-base">Favorite Places</h3>
              </div>
              <button onClick={() => setShowPlacesSheet(false)} className="p-1.5 rounded-full hover:bg-white/10">
                <X size={18} />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto space-y-2">
              {savedPlaces.map((place) => (
                <div
                  key={place.name}
                  onClick={() => {
                    setPin({ lat: place.lat, lng: place.lng });
                    setSimulated({ lat: place.lat, lng: place.lng });
                    setIsSpoofing(true);
                    setShowPlacesSheet(false);
                  }}
                  className="p-3.5 rounded-2xl bg-white/5 hover:bg-white/10 cursor-pointer border border-white/5 flex items-center justify-between transition active:scale-98"
                >
                  <div>
                    <div className="font-semibold text-sm">{place.name}</div>
                    <div className="text-xs text-white/50">{place.desc}</div>
                    <div className="font-mono text-[11px] text-cyan-400 mt-1">
                      {place.lat.toFixed(4)}, {place.lng.toFixed(4)}
                    </div>
                  </div>
                  <ChevronRight size={16} className="text-white/40" />
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Settings Sheet Modal */}
      {showSettingsSheet && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-end md:items-center justify-center p-0 md:p-6">
          <div className="w-full max-w-lg bg-[#141A26] rounded-t-3xl md:rounded-3xl border border-white/15 p-6 space-y-4 shadow-2xl">
            <div className="flex items-center justify-between border-b border-white/10 pb-3">
              <div className="flex items-center gap-2">
                <Settings className="text-cyan-400" size={20} />
                <h3 className="font-bold text-base">Locus Settings</h3>
              </div>
              <button onClick={() => setShowSettingsSheet(false)} className="p-1.5 rounded-full hover:bg-white/10">
                <X size={18} />
              </button>
            </div>

            <div className="space-y-3 text-xs">
              <div className="p-3 rounded-2xl bg-white/5 border border-white/10 flex justify-between items-center">
                <span>Theme Accent</span>
                <div className="flex gap-2">
                  {(['mint', 'cyberpunk', 'electric'] as const).map(t => (
                    <button
                      key={t}
                      onClick={() => setTheme(t)}
                      className={`px-3 py-1 rounded-full uppercase text-[10px] font-bold ${
                        theme === t ? 'bg-cyan-400 text-black' : 'bg-white/10'
                      }`}
                    >
                      {t}
                    </button>
                  ))}
                </div>
              </div>

              <div className="p-3 rounded-2xl bg-white/5 border border-white/10 flex justify-between items-center">
                <span>Background Keep-Alive</span>
                <span className="text-emerald-400 font-semibold">Silent Audio Active</span>
              </div>

              <div className="p-3 rounded-2xl bg-white/5 border border-white/10 flex justify-between items-center">
                <span>CoreDevice Tunnel</span>
                <span className="text-cyan-400 font-semibold">Local Loopback (Port 58783)</span>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
