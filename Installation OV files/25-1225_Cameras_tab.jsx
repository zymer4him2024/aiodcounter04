import React, { useState, useEffect } from 'react';
import { collection, query, where, onSnapshot, doc, updateDoc, deleteDoc, addDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '../firebase';

const Cameras = ({ user }) => {
  const [approvedCameras, setApprovedCameras] = useState([]);
  const [pendingCameras, setPendingCameras] = useState([]);
  const [sites, setSites] = useState([]);
  const [showApprovalModal, setShowApprovalModal] = useState(false);
  const [selectedPendingCamera, setSelectedPendingCamera] = useState(null);
  const [approvalForm, setApprovalForm] = useState({ cameraName: '', siteId: '' });
  const [loading, setLoading] = useState(true);

  // Fetch approved cameras
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
      const cameras = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setApprovedCameras(cameras);
      setLoading(false);
    });

    return () => unsubscribe();
  }, [user]);

  // Fetch pending cameras (superadmin only)
  useEffect(() => {
    if (!user || user.role !== 'superadmin') return;

    const q = query(collection(db, 'pending_cameras'));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const pending = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setPendingCameras(pending);
    });

    return () => unsubscribe();
  }, [user]);

  // Fetch sites for approval dropdown
  useEffect(() => {
    if (!user) return;

    const q = query(collection(db, 'sites'));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const sitesData = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setSites(sitesData);
    });

    return () => unsubscribe();
  }, [user]);

  const handleApproveClick = (pendingCamera) => {
    setSelectedPendingCamera(pendingCamera);
    setApprovalForm({ cameraName: '', siteId: '' });
    setShowApprovalModal(true);
  };

  const handleApprove = async () => {
    if (!approvalForm.cameraName || !approvalForm.siteId) {
      alert('Please fill in all fields');
      return;
    }

    try {
      const selectedSite = sites.find(s => s.id === approvalForm.siteId);
      
      // Create camera document
      await addDoc(collection(db, 'cameras'), {
        cameraName: approvalForm.cameraName,
        deviceId: selectedPendingCamera.deviceId,
        siteId: approvalForm.siteId,
        siteName: selectedSite?.name || '',
        subadminId: selectedSite?.subadminId || '',
        status: 'offline',
        ipAddress: selectedPendingCamera.ipAddress,
        macAddress: selectedPendingCamera.macAddress,
        hardwareInfo: selectedPendingCamera.hardwareInfo,
        approvedBy: user.uid,
        approvedAt: serverTimestamp(),
        createdAt: serverTimestamp()
      });

      // Delete from pending
      await deleteDoc(doc(db, 'pending_cameras', selectedPendingCamera.id));

      // Update site's camera count
      if (selectedSite) {
        const siteRef = doc(db, 'sites', approvalForm.siteId);
        await updateDoc(siteRef, {
          assignedCameras: [...(selectedSite.assignedCameras || []), selectedPendingCamera.deviceId]
        });
      }

      setShowApprovalModal(false);
      alert('Camera approved successfully!');
    } catch (error) {
      console.error('Error approving camera:', error);
      alert('Failed to approve camera');
    }
  };

  const handleReject = async (pendingCamera) => {
    if (!confirm('Are you sure you want to reject this camera?')) return;

    try {
      await deleteDoc(doc(db, 'pending_cameras', pendingCamera.id));
      alert('Camera rejected');
    } catch (error) {
      console.error('Error rejecting camera:', error);
      alert('Failed to reject camera');
    }
  };

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

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-xl">Loading cameras...</div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Approved Cameras Section */}
      <div>
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-2xl font-bold">Approved Cameras</h2>
          <span className="text-sm text-gray-500">
            {approvedCameras.length} camera{approvedCameras.length !== 1 ? 's' : ''}
          </span>
        </div>

        {approvedCameras.length === 0 ? (
          <div className="bg-white p-8 rounded-lg shadow text-center text-gray-500">
            No approved cameras yet
          </div>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {approvedCameras.map(camera => {
              const systemHealth = camera.systemHealth || {};
              const detectorStatus = camera.detectorStatus || {};

              return (
                <div key={camera.id} className="bg-white rounded-lg shadow-lg overflow-hidden">
                  {/* Header */}
                  <div className="bg-gradient-to-r from-blue-600 to-blue-700 p-4 text-white">
                    <div className="flex justify-between items-start">
                      <div>
                        <h3 className="text-xl font-bold">{camera.cameraName || camera.name}</h3>
                        <p className="text-sm text-blue-100">{camera.siteName || 'No Site'}</p>
                      </div>
                      <div className="flex items-center gap-2">
                        <span className={`inline-block w-3 h-3 rounded-full ${
                          camera.status === 'online' ? 'bg-green-400' : 'bg-red-400'
                        }`}></span>
                        <span className="text-sm font-medium">
                          {camera.status === 'online' ? 'Online' : 'Offline'}
                        </span>
                      </div>
                    </div>
                  </div>

                  {/* Camera Info */}
                  <div className="p-4 border-b bg-gray-50">
                    <div className="grid grid-cols-3 gap-4 text-sm">
                      <div>
                        <div className="text-gray-500">FPS</div>
                        <div className="font-semibold text-lg">
                          {camera.fps?.toFixed(1) || '0.0'}
                        </div>
                      </div>
                      <div>
                        <div className="text-gray-500">Frames</div>
                        <div className="font-semibold text-lg">
                          {camera.frameCount?.toLocaleString() || '0'}
                        </div>
                      </div>
                      <div>
                        <div className="text-gray-500">Last Seen</div>
                        <div className="font-semibold text-xs">
                          {camera.lastSeen?.toDate
                            ? new Date(camera.lastSeen.toDate()).toLocaleTimeString()
                            : 'Never'}
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Hardware Status */}
                  <div className="p-4">
                    <h4 className="font-bold text-sm text-gray-700 mb-3">Hardware Status</h4>
                    
                    <div className="grid grid-cols-2 gap-4">
                      {/* Raspberry Pi */}
                      <div className="border rounded-lg p-3 bg-pink-50">
                        <div className="flex items-center gap-2 mb-2">
                          <svg className="w-4 h-4 text-pink-600" fill="currentColor" viewBox="0 0 24 24">
                            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2z"/>
                          </svg>
                          <span className="font-bold text-xs text-pink-700">Raspberry Pi</span>
                        </div>

                        <div className="space-y-2">
                          {/* CPU Temperature */}
                          <div>
                            <div className="flex justify-between items-center mb-1">
                              <span className="text-xs text-gray-600">CPU Temp</span>
                              <span className={`text-xs font-bold ${getTemperatureColor(systemHealth.cpuTemp)}`}>
                                {systemHealth.cpuTemp ? `${systemHealth.cpuTemp}°C` : 'N/A'}
                              </span>
                            </div>
                            {systemHealth.cpuTemp && (
                              <div className="w-full bg-gray-200 rounded-full h-1.5">
                                <div 
                                  className={`h-1.5 rounded-full ${
                                    systemHealth.cpuTemp < 60 ? 'bg-green-500' :
                                    systemHealth.cpuTemp < 75 ? 'bg-yellow-500' : 'bg-red-500'
                                  }`}
                                  style={{ width: `${Math.min(systemHealth.cpuTemp / 85 * 100, 100)}%` }}
                                ></div>
                              </div>
                            )}
                          </div>

                          {/* CPU & Memory */}
                          <div className="flex justify-between text-xs">
                            <span className="text-gray-600">CPU:</span>
                            <span className="font-semibold">
                              {systemHealth.cpuUsage ? `${systemHealth.cpuUsage}%` : 'N/A'}
                            </span>
                          </div>
                          <div className="flex justify-between text-xs">
                            <span className="text-gray-600">Memory:</span>
                            <span className="font-semibold">
                              {systemHealth.memoryUsage ? `${systemHealth.memoryUsage}%` : 'N/A'}
                            </span>
                          </div>
                        </div>
                      </div>

                      {/* Hailo */}
                      <div className="border rounded-lg p-3 bg-blue-50">
                        <div className="flex items-center gap-2 mb-2">
                          <svg className="w-4 h-4 text-blue-600" fill="currentColor" viewBox="0 0 24 24">
                            <path d="M20 6h-2.18c.11-.31.18-.65.18-1a2.996 2.996 0 0 0-5.5-1.65l-.5.67-.5-.68C10.96 2.54 10.05 2 9 2 7.34 2 6 3.34 6 5c0 .35.07.69.18 1H4c-1.11 0-1.99.89-1.99 2L2 19c0 1.11.89 2 2 2h16c1.11 0 2-.89 2-2V8c0-1.11-.89-2-2-2z"/>
                          </svg>
                          <span className="font-bold text-xs text-blue-700">Hailo-8 AI</span>
                        </div>

                        <div className="space-y-2">
                          {/* Hailo Temperature */}
                          {systemHealth.hailoTemp && (
                            <div>
                              <div className="flex justify-between items-center mb-1">
                                <span className="text-xs text-gray-600">Chip Temp</span>
                                <span className={`text-xs font-bold ${getTemperatureColor(systemHealth.hailoTemp)}`}>
                                  {systemHealth.hailoTemp}°C
                                </span>
                              </div>
                              <div className="w-full bg-gray-200 rounded-full h-1.5">
                                <div 
                                  className={`h-1.5 rounded-full ${
                                    systemHealth.hailoTemp < 60 ? 'bg-green-500' :
                                    systemHealth.hailoTemp < 75 ? 'bg-yellow-500' : 'bg-red-500'
                                  }`}
                                  style={{ width: `${Math.min(systemHealth.hailoTemp / 85 * 100, 100)}%` }}
                                ></div>
                              </div>
                            </div>
                          )}

                          {/* Status */}
                          <div className="flex justify-between text-xs">
                            <span className="text-gray-600">Status:</span>
                            <span className={`font-semibold ${
                              detectorStatus.hailo_active ? 'text-green-600' : 'text-red-600'
                            }`}>
                              {detectorStatus.hailo_active ? '✓ Active' : '✗ Inactive'}
                            </span>
                          </div>

                          <div className="flex justify-between text-xs">
                            <span className="text-gray-600">Tracks:</span>
                            <span className="font-semibold">{detectorStatus.active_tracks || 0}</span>
                          </div>

                          <div className="flex justify-between text-xs">
                            <span className="text-gray-600">Counted:</span>
                            <span className="font-semibold">
                              {detectorStatus.total_counted?.toLocaleString() || '0'}
                            </span>
                          </div>
                        </div>
                      </div>
                    </div>

                    {/* Warnings */}
                    {(systemHealth.cpuTemp >= 80 || systemHealth.hailoTemp >= 85) && (
                      <div className="mt-3 p-2 bg-red-50 border border-red-200 rounded text-xs text-red-700">
                        ⚠️ High temperature detected! Check cooling.
                      </div>
                    )}
                  </div>

                  {/* Device Info */}
                  <div className="p-4 bg-gray-50 border-t text-xs text-gray-600">
                    <div className="grid grid-cols-2 gap-2">
                      <div>
                        <span className="font-semibold">Device ID:</span>
                        <div className="font-mono text-xs truncate">{camera.deviceId}</div>
                      </div>
                      <div>
                        <span className="font-semibold">IP:</span>
                        <div className="font-mono">{camera.ipAddress || 'N/A'}</div>
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Pending Cameras Section - Superadmin Only */}
      {user?.role === 'superadmin' && (
        <div>
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-2xl font-bold">Pending Camera Approvals</h2>
            <span className="px-3 py-1 bg-yellow-100 text-yellow-800 rounded-full text-sm font-medium">
              {pendingCameras.length} pending
            </span>
          </div>

          {pendingCameras.length === 0 ? (
            <div className="bg-white p-8 rounded-lg shadow text-center text-gray-500">
              No pending cameras
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {pendingCameras.map(camera => (
                <div key={camera.id} className="bg-white rounded-lg shadow-lg border-2 border-yellow-200">
                  <div className="bg-yellow-50 p-4 border-b border-yellow-200">
                    <div className="flex items-center gap-2 mb-2">
                      <svg className="w-6 h-6 text-yellow-600" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>
                      </svg>
                      <h3 className="text-lg font-bold text-yellow-900">New Camera</h3>
                    </div>
                    <span className="inline-block px-2 py-1 bg-yellow-200 text-yellow-800 rounded text-xs font-semibold">
                      Pending Approval
                    </span>
                  </div>

                  <div className="p-4 space-y-3">
                    <div>
                      <div className="text-xs text-gray-500 font-semibold mb-1">DEVICE ID</div>
                      <div className="text-sm font-mono bg-gray-50 p-2 rounded break-all">
                        {camera.deviceId}
                      </div>
                    </div>

                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <div className="text-xs text-gray-500 font-semibold mb-1">MAC</div>
                        <div className="text-sm font-mono">{camera.macAddress}</div>
                      </div>
                      <div>
                        <div className="text-xs text-gray-500 font-semibold mb-1">IP</div>
                        <div className="text-sm font-mono">{camera.ipAddress}</div>
                      </div>
                    </div>

                    <div>
                      <div className="text-xs text-gray-500 font-semibold mb-1">HARDWARE</div>
                      <div className="flex items-center gap-2 text-sm">
                        <svg className="w-4 h-4 text-pink-600" fill="currentColor" viewBox="0 0 24 24">
                          <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2z"/>
                        </svg>
                        <span>{camera.hardwareInfo?.model || 'Raspberry Pi 5'}</span>
                      </div>
                      {camera.hardwareInfo?.hasHailo && (
                        <div className="flex items-center gap-2 text-sm mt-1">
                          <svg className="w-4 h-4 text-green-600" fill="currentColor" viewBox="0 0 24 24">
                            <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/>
                          </svg>
                          <span className="text-green-700 font-semibold">Hailo-8 Detected</span>
                        </div>
                      )}
                    </div>

                    <div className="text-xs text-gray-500">
                      Registered: {camera.createdAt?.toDate?.()?.toLocaleString() || 'Unknown'}
                    </div>
                  </div>

                  <div className="p-4 bg-gray-50 border-t flex gap-2">
                    <button
                      onClick={() => handleApproveClick(camera)}
                      className="flex-1 bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 font-medium text-sm flex items-center justify-center gap-2"
                    >
                      <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/>
                      </svg>
                      Approve
                    </button>
                    <button
                      onClick={() => handleReject(camera)}
                      className="flex-1 bg-red-600 text-white px-4 py-2 rounded-md hover:bg-red-700 font-medium text-sm flex items-center justify-center gap-2"
                    >
                      <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/>
                      </svg>
                      Reject
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Approval Modal */}
      {showApprovalModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full">
            <div className="p-6">
              <h3 className="text-xl font-bold mb-4">Approve Camera</h3>
              
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Camera Name *
                  </label>
                  <input
                    type="text"
                    value={approvalForm.cameraName}
                    onChange={(e) => setApprovalForm({ ...approvalForm, cameraName: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="e.g., Main Entrance Camera"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Assign to Site *
                  </label>
                  <select
                    value={approvalForm.siteId}
                    onChange={(e) => setApprovalForm({ ...approvalForm, siteId: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  >
                    <option value="">Select a site...</option>
                    {sites.map(site => (
                      <option key={site.id} value={site.id}>
                        {site.name} - {site.location}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="flex gap-3 mt-6">
                <button
                  onClick={() => setShowApprovalModal(false)}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-md hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  onClick={handleApprove}
                  className="flex-1 bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 font-medium"
                >
                  Approve
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Cameras;
