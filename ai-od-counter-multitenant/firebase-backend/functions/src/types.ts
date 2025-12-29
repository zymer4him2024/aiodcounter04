import { Timestamp } from 'firebase-admin/firestore';

export interface Superadmin {
  email: string;
  name: string;
  companyName: string;
  createdAt: Timestamp;
  role: 'superadmin';
}

export interface Subadmin {
  email: string;
  name: string;
  companyName: string;
  createdAt: Timestamp;
  createdBy: string; // superadminId reference
  role: 'subadmin';
  assignedSites: string[]; // array of siteIds
}

export interface Site {
  name: string;
  location: string;
  subadminId: string; // owner reference
  createdBy: string; // superadminId reference
  createdAt: Timestamp;
  status: 'active' | 'inactive';
  assignedCameras: string[]; // array of cameraIds
}

export interface Camera {
  name: string;
  deviceToken: string; // unique secure token
  deviceId: string; // NEW: from pending_cameras
  siteId: string; // reference
  subadminId: string; // reference
  status: 'online' | 'offline' | 'pending';
  lastSeen: Timestamp;
  ipAddress: string;
  macAddress: string;
  modelType: string;
  createdBy: string; // superadminId reference
  createdAt: Timestamp;
  approvedBy?: string; // NEW: for handshake tracking
  approvedAt?: Timestamp; // NEW: for handshake tracking
  
  // NEW: Hardware monitoring fields
  fps?: number; // Current frames per second
  frameCount?: number; // Total frames processed
  
  detectorStatus?: {
    camera_active: boolean;
    model_loaded: boolean;
    hailo_active: boolean;
    fps?: number;
    active_tracks: number;
    total_counted: number;
    error_count: number;
    uptime_seconds: number;
  };
  
  systemHealth?: {
    cpuTemp?: number; // Raspberry Pi CPU temperature (°C)
    hailoTemp?: number; // Hailo chip temperature (°C)
    cpuUsage?: number; // CPU usage percentage
    memoryUsage?: number; // Memory usage percentage
    timestamp: Timestamp;
  };
}

export interface CameraSession {
  cameraId: string;
  siteId: string;
  startTime: Timestamp;
  endTime: Timestamp | null;
  status: 'active' | 'completed';
  totalCounts: number;
}

export interface Count {
  cameraId: string;
  siteId: string;
  subadminId: string;
  sessionId: string;
  timestamp: Timestamp;
  objectType: string;
  count: number;
  confidence: number;
  metadata?: {
    bbox?: number[];
    image_url?: string;
    [key: string]: any;
  };
}

// NEW: For camera self-registration
export interface PendingCamera {
  deviceId: string;
  macAddress: string;
  ipAddress: string;
  hardwareInfo: {
    model: string;
    hailo: boolean;
    cpuSerial: string;
  };
  registeredAt: Timestamp;
  status: 'pending';
  lastSeen: Timestamp;
  location?: string;
}




