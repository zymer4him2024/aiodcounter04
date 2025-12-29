import React, { useState, useEffect } from 'react';
import { collection, query, where, onSnapshot, orderBy, limit, getDocs } from 'firebase/firestore';
import { db } from './firebase';
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';

const LiveCounts = ({ user }) => {
  const [cameras, setCameras] = useState([]);
  const [selectedCamera, setSelectedCamera] = useState(null);
  const [latestCounts, setLatestCounts] = useState({});
  const [historicalData, setHistoricalData] = useState([]);
  const [timeRange, setTimeRange] = useState('1h');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!user) return;

    let q;
    if (user.role === 'superadmin') {
      q = query(collection(db, 'cameras'));
    } else if (user.role === 'subadmin') {
      q = query(collection(db, 'cameras'), where('subadminId', '==', user.uid));
    } else {
      q = query(collection(db, 'cameras'), where('viewerIds', 'array-contains', user.uid));
    }

    const unsubscribe = onSnapshot(q, (snapshot) => {
      const cameraData = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setCameras(cameraData);
      
      if (cameraData.length > 0 && !selectedCamera) {
        setSelectedCamera(cameraData[0].id);
      }
      
      setLoading(false);
    });

    return () => unsubscribe();
  }, [user, selectedCamera]);

  useEffect(() => {
    if (!selectedCamera) return;

    const countsRef = collection(db, 'cameras', selectedCamera, 'counts');
    const q = query(countsRef, orderBy('timestamp', 'desc'), limit(1));

    const unsubscribe = onSnapshot(q, (snapshot) => {
      if (!snapshot.empty) {
        const latestCount = snapshot.docs[0].data();
        setLatestCounts(latestCount);
      }
    });

    return () => unsubscribe();
  }, [selectedCamera]);

  useEffect(() => {
    if (!selectedCamera) return;

    const fetchHistoricalData = async () => {
      const now = new Date();
      let startTime = new Date();

      switch (timeRange) {
        case '1h':
          startTime.setHours(now.getHours() - 1);
          break;
        case '6h':
          startTime.setHours(now.getHours() - 6);
          break;
        case '24h':
          startTime.setHours(now.getHours() - 24);
          break;
        case '7d':
          startTime.setDate(now.getDate() - 7);
          break;
        default:
          startTime.setHours(now.getHours() - 1);
      }

      const countsRef = collection(db, 'cameras', selectedCamera, 'counts');
      const q = query(
        countsRef,
        where('timestamp', '>=', startTime.toISOString()),
        orderBy('timestamp', 'asc')
      );

      const snapshot = await getDocs(q);
      const data = snapshot.docs.map(doc => {
        const countData = doc.data();
        return {
          time: new Date(countData.timestamp).toLocaleTimeString(),
          timestamp: countData.timestamp,
          ...countData.counts,
          total: countData.total || 0
        };
      });

      setHistoricalData(data);
    };

    fetchHistoricalData();
    const interval = setInterval(fetchHistoricalData, 30000);

    return () => clearInterval(interval);
  }, [selectedCamera, timeRange]);

  const selectedCameraData = cameras.find(c => c.id === selectedCamera);

  const getTemperatureColor = (temp) => {
    if (!temp) return 'text-gray-500';
    if (temp < 60) return 'text-green-600';
    if (temp < 75) return 'text-yellow-600';
    return 'text-red-600';
  };

  const getTemperatureStatus = (temp) => {
    if (!temp) return 'Unknown';
    if (temp < 60) return 'Normal';
    if (temp < 75) return 'Warm';
    if (temp < 85) return 'Hot';
    return 'Critical!';
  };

  const getMemoryColor = (percent) => {
    if (!percent) return 'bg-gray-300';
    if (percent < 70) return 'bg-green-500';
    if (percent < 85) return 'bg-yellow-500';
    return 'bg-red-500';
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-xl">Loading cameras...</div>
      </div>
    );
  }

  if (cameras.length === 0) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-xl text-gray-500">No cameras available</div>
      </div>
    );
  }

  const detectorStatus = selectedCameraData?.detectorStatus || {};
  const systemHealth = selectedCameraData?.systemHealth || {};
  
  return (
    <div className="space-y-6">
      {/* Camera Selector */}
      <div className="bg-white p-4 rounded-lg shadow">
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Select Camera
        </label>
        <select
          value={selectedCamera || ''}
          onChange={(e) => setSelectedCamera(e.target.value)}
          className="w-full md:w-96 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          {cameras.map(camera => (
            <option key={camera.id} value={camera.id}>
              {camera.cameraName} - {camera.siteName || 'No Site'}
            </option>
          ))}
        </select>
      </div>

      {selectedCameraData && (
        <>
          {/* Camera Status Card */}
          <div className="bg-white p-6 rounded-lg shadow">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-2xl font-bold">{selectedCameraData.cameraName}</h2>
              <div className="flex items-center gap-2">
                <span className={`inline-block w-3 h-3 rounded-full ${
                  selectedCameraData.status === 'online' ? 'bg-green-500' : 'bg-red-500'
                }`}></span>
                <span className="text-sm font-medium">
                  {selectedCameraData.status === 'online' ? 'Online' : 'Offline'}
                </span>
              </div>
            </div>

            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <div>
                <div className="text-sm text-gray-500">FPS</div>
                <div className="text-2xl font-bold">
                  {selectedCameraData.fps?.toFixed(1) || '0.0'}
                </div>
              </div>
              <div>
                <div className="text-sm text-gray-500">Site</div>
                <div className="text-lg font-semibold">
                  {selectedCameraData.siteName || 'N/A'}
                </div>
              </div>
              <div>
                <div className="text-sm text-gray-500">Last Seen</div>
                <div className="text-sm">
                  {selectedCameraData.lastSeen?.toDate
                    ? new Date(selectedCameraData.lastSeen.toDate()).toLocaleString()
                    : 'Never'}
                </div>
              </div>
              <div>
                <div className="text-sm text-gray-500">Frame Count</div>
                <div className="text-lg font-semibold">
                  {selectedCameraData.frameCount?.toLocaleString() || '0'}
                </div>
              </div>
            </div>
          </div>

          {/* Hardware Status Card */}
          <div className="bg-white p-6 rounded-lg shadow">
            <h3 className="text-xl font-bold mb-4">Hardware Status</h3>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Raspberry Pi Status */}
              <div className="border rounded-lg p-4">
                <div className="flex items-center gap-2 mb-3">
                  <svg className="w-6 h-6 text-pink-600" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/>
                  </svg>
                  <h4 className="font-bold text-lg">Raspberry Pi 5</h4>
                </div>

                <div className="space-y-3">
                  {/* CPU Temperature */}
                  <div>
                    <div className="flex justify-between items-center mb-1">
                      <span className="text-sm text-gray-600">CPU Temperature</span>
                      <span className={`text-sm font-bold ${getTemperatureColor(systemHealth.cpuTemp)}`}>
                        {systemHealth.cpuTemp ? `${systemHealth.cpuTemp}°C` : 'N/A'}
                      </span>
                    </div>
                    {systemHealth.cpuTemp && (
                      <>
                        <div className="w-full bg-gray-200 rounded-full h-2">
                          <div 
                            className={`h-2 rounded-full transition-all ${
                              systemHealth.cpuTemp < 60 ? 'bg-green-500' :
                              systemHealth.cpuTemp < 75 ? 'bg-yellow-500' : 'bg-red-500'
                            }`}
                            style={{ width: `${Math.min(systemHealth.cpuTemp / 85 * 100, 100)}%` }}
                          ></div>
                        </div>
                        <div className="text-xs text-gray-500 mt-1">
                          {getTemperatureStatus(systemHealth.cpuTemp)}
                        </div>
                      </>
                    )}
                    {systemHealth.cpuTemp >= 80 && (
                      <div className="mt-2 p-2 bg-red-50 border border-red-200 rounded text-xs text-red-700">
                        ⚠️ High temperature! Check cooling.
                      </div>
                    )}
                  </div>

                  {/* CPU Usage */}
                  <div>
                    <div className="flex justify-between items-center mb-1">
                      <span className="text-sm text-gray-600">CPU Usage</span>
                      <span className="text-sm font-bold">
                        {systemHealth.cpuUsage ? `${systemHealth.cpuUsage}%` : 'N/A'}
                      </span>
                    </div>
                    {systemHealth.cpuUsage && (
                      <div className="w-full bg-gray-200 rounded-full h-2">
                        <div 
                          className={`h-2 rounded-full ${getMemoryColor(systemHealth.cpuUsage)}`}
                          style={{ width: `${systemHealth.cpuUsage}%` }}
                        ></div>
                      </div>
                    )}
                  </div>

                  {/* Memory */}
                  <div>
                    <div className="flex justify-between items-center mb-1">
                      <span className="text-sm text-gray-600">Memory Usage</span>
                      <span className="text-sm font-bold">
                        {systemHealth.memoryUsage ? `${systemHealth.memoryUsage}%` : 'N/A'}
                      </span>
                    </div>
                    {systemHealth.memoryUsage && (
                      <div className="w-full bg-gray-200 rounded-full h-2">
                        <div 
                          className={`h-2 rounded-full ${getMemoryColor(systemHealth.memoryUsage)}`}
                          style={{ width: `${systemHealth.memoryUsage}%` }}
                        ></div>
                      </div>
                    )}
                  </div>

                  {/* Uptime */}
                  <div className="flex justify-between items-center pt-2 border-t">
                    <span className="text-sm text-gray-600">Uptime</span>
                    <span className="text-sm font-semibold">
                      {detectorStatus.uptime_seconds 
                        ? `${Math.floor(detectorStatus.uptime_seconds / 3600)}h ${Math.floor((detectorStatus.uptime_seconds % 3600) / 60)}m`
                        : 'N/A'}
                    </span>
                  </div>
                </div>
              </div>

              {/* Hailo Accelerator Status */}
              <div className="border rounded-lg p-4">
                <div className="flex items-center gap-2 mb-3">
                  <svg className="w-6 h-6 text-blue-600" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M20 6h-2.18c.11-.31.18-.65.18-1a2.996 2.996 0 0 0-5.5-1.65l-.5.67-.5-.68C10.96 2.54 10.05 2 9 2 7.34 2 6 3.34 6 5c0 .35.07.69.18 1H4c-1.11 0-1.99.89-1.99 2L2 19c0 1.11.89 2 2 2h16c1.11 0 2-.89 2-2V8c0-1.11-.89-2-2-2zm-5-2c.55 0 1 .45 1 1s-.45 1-1 1-1-.45-1-1 .45-1 1-1zM9 4c.55 0 1 .45 1 1s-.45 1-1 1-1-.45-1-1 .45-1 1-1zm11 15H4v-2h16v2zm0-5H4V8h5.08L7 10.83 8.62 12 11 8.76l1-1.36 1 1.36L15.38 12 17 10.83 14.92 8H20v6z"/>
                  </svg>
                  <h4 className="font-bold text-lg">Hailo-8 AI</h4>
                </div>

                <div className="space-y-3">
                  {/* Hailo Temperature - NEW! */}
                  {systemHealth.hailoTemp && (
                    <div>
                      <div className="flex justify-between items-center mb-1">
                        <span className="text-sm text-gray-600">Hailo Temperature</span>
                        <span className={`text-sm font-bold ${getTemperatureColor(systemHealth.hailoTemp)}`}>
                          {systemHealth.hailoTemp}°C
                        </span>
                      </div>
                      <div className="w-full bg-gray-200 rounded-full h-2">
                        <div 
                          className={`h-2 rounded-full transition-all ${
                            systemHealth.hailoTemp < 60 ? 'bg-green-500' :
                            systemHealth.hailoTemp < 75 ? 'bg-yellow-500' : 'bg-red-500'
                          }`}
                          style={{ width: `${Math.min(systemHealth.hailoTemp / 85 * 100, 100)}%` }}
                        ></div>
                      </div>
                      <div className="text-xs text-gray-500 mt-1">
                        {getTemperatureStatus(systemHealth.hailoTemp)}
                      </div>
                      {systemHealth.hailoTemp >= 85 && (
                        <div className="mt-2 p-2 bg-red-50 border border-red-200 rounded text-xs text-red-700">
                          ⚠️ Hailo overheating! Reduce workload.
                        </div>
                      )}
                    </div>
                  )}

                  {/* Accelerator Status */}
                  <div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-600">Accelerator Status</span>
                      <span className={`text-sm font-bold ${
                        detectorStatus.hailo_active ? 'text-green-600' : 'text-red-600'
                      }`}>
                        {detectorStatus.hailo_active ? '✓ Active' : '✗ Inactive'}
                      </span>
                    </div>
                  </div>

                  {/* Model Loaded */}
                  <div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-600">Model Loaded</span>
                      <span className={`text-sm font-bold ${
                        detectorStatus.model_loaded ? 'text-green-600' : 'text-gray-400'
                      }`}>
                        {detectorStatus.model_loaded ? '✓ Yes' : '✗ No'}
                      </span>
                    </div>
                  </div>

                  {/* Camera Active */}
                  <div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-600">Camera Active</span>
                      <span className={`text-sm font-bold ${
                        detectorStatus.camera_active ? 'text-green-600' : 'text-red-600'
                      }`}>
                        {detectorStatus.camera_active ? '✓ Active' : '✗ Inactive'}
                      </span>
                    </div>
                  </div>

                  {/* Active Tracks */}
                  <div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-600">Active Tracks</span>
                      <span className="text-sm font-bold">
                        {detectorStatus.active_tracks || 0}
                      </span>
                    </div>
                  </div>

                  {/* Total Counted */}
                  <div className="flex justify-between items-center pt-2 border-t">
                    <span className="text-sm text-gray-600">Total Counted</span>
                    <span className="text-sm font-semibold">
                      {detectorStatus.total_counted?.toLocaleString() || '0'}
                    </span>
                  </div>

                  {/* Error Count */}
                  {detectorStatus.error_count > 0 && (
                    <div className="mt-2 p-2 bg-yellow-50 border border-yellow-200 rounded text-xs text-yellow-700">
                      ⚠️ {detectorStatus.error_count} errors detected
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>

          {/* Latest Counts */}
          <div className="bg-white p-6 rounded-lg shadow">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-xl font-bold">Latest Counts (Last 2 Minutes)</h3>
              <div className="text-sm text-gray-500">
                {latestCounts.timestamp 
                  ? new Date(latestCounts.timestamp).toLocaleTimeString()
                  : 'No data'}
              </div>
            </div>

            {latestCounts.counts ? (
              <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
                {Object.entries(latestCounts.counts).map(([key, value]) => (
                  <div key={key} className="text-center p-4 bg-gray-50 rounded-lg">
                    <div className="text-3xl font-bold text-blue-600">{value}</div>
                    <div className="text-sm text-gray-600 capitalize mt-1">{key}</div>
                  </div>
                ))}
                <div className="text-center p-4 bg-blue-50 rounded-lg">
                  <div className="text-3xl font-bold text-blue-800">
                    {latestCounts.total || 0}
                  </div>
                  <div className="text-sm text-gray-600 font-semibold mt-1">Total</div>
                </div>
              </div>
            ) : (
              <div className="text-center text-gray-500 py-8">
                No counts data available
              </div>
            )}
          </div>

          {/* Time Range Selector */}
          <div className="bg-white p-4 rounded-lg shadow">
            <div className="flex gap-2">
              {['1h', '6h', '24h', '7d'].map(range => (
                <button
                  key={range}
                  onClick={() => setTimeRange(range)}
                  className={`px-4 py-2 rounded-md font-medium ${
                    timeRange === range
                      ? 'bg-blue-600 text-white'
                      : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                  }`}
                >
                  {range.toUpperCase()}
                </button>
              ))}
            </div>
          </div>

          {/* Charts */}
          <div className="bg-white p-6 rounded-lg shadow">
            <h3 className="text-xl font-bold mb-4">Object Detection Over Time</h3>
            {historicalData.length > 0 ? (
              <ResponsiveContainer width="100%" height={400}>
                <LineChart data={historicalData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="time" tick={{ fontSize: 12 }} angle={-45} textAnchor="end" height={80} />
                  <YAxis />
                  <Tooltip />
                  <Legend />
                  <Line type="monotone" dataKey="person" stroke="#8884d8" name="Person" />
                  <Line type="monotone" dataKey="car" stroke="#82ca9d" name="Car" />
                  <Line type="monotone" dataKey="motorcycle" stroke="#ffc658" name="Motorcycle" />
                  <Line type="monotone" dataKey="bus" stroke="#ff7c7c" name="Bus" />
                  <Line type="monotone" dataKey="truck" stroke="#8dd1e1" name="Truck" />
                </LineChart>
              </ResponsiveContainer>
            ) : (
              <div className="text-center text-gray-500 py-16">
                No historical data available
              </div>
            )}
          </div>

          <div className="bg-white p-6 rounded-lg shadow">
            <h3 className="text-xl font-bold mb-4">Total Counts by Type</h3>
            {historicalData.length > 0 ? (
              <ResponsiveContainer width="100%" height={300}>
                <BarChart data={historicalData.slice(-10)}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="time" tick={{ fontSize: 12 }} />
                  <YAxis />
                  <Tooltip />
                  <Legend />
                  <Bar dataKey="person" fill="#8884d8" name="Person" />
                  <Bar dataKey="car" fill="#82ca9d" name="Car" />
                  <Bar dataKey="motorcycle" fill="#ffc658" name="Motorcycle" />
                  <Bar dataKey="bus" fill="#ff7c7c" name="Bus" />
                  <Bar dataKey="truck" fill="#8dd1e1" name="Truck" />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <div className="text-center text-gray-500 py-16">
                No data to display
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
};

export default LiveCounts;
