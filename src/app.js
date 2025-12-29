import React, { useState, useEffect } from 'react';
import { collection, query, where, onSnapshot, getDocs, deleteDoc, doc } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { db, functions } from './firebase';
import { Wifi, Cpu, CheckCircle, XCircle } from 'lucide-react';
import './App.css';

function App() {
  const [cameras, setCameras] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedCamera, setSelectedCamera] = useState(null);
  const [sites, setSites] = useState([]);
  const [cameraName, setCameraName] = useState('');
  const [selectedSite, setSelectedSite] = useState('');
  const [approving, setApproving] = useState(false);

  useEffect(() => {
    const q = query(collection(db, 'pending_cameras'), where('status', '==', 'pending'));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const data = [];
      snapshot.forEach((doc) => {
        data.push({ id: doc.id, ...doc.data() });
      });
      setCameras(data);
      setLoading(false);
    });
    return () => unsubscribe();
  }, []);

  useEffect(() => {
    const loadSites = async () => {
      const sitesSnapshot = await getDocs(collection(db, 'sites'));
      const sitesData = [];
      sitesSnapshot.forEach((doc) => {
        sitesData.push({ id: doc.id, ...doc.data() });
      });
      setSites(sitesData);
    };
    loadSites();
  }, []);

  const handleReject = async (camera) => {
    if (!window.confirm('Reject this camera?')) return;
    try {
      await deleteDoc(doc(db, 'pending_cameras', camera.id));
      alert('Camera rejected');
    } catch (error) {
      alert('Failed: ' + error.message);
    }
  };

  const handleApprove = async () => {
    if (!cameraName || !selectedSite) {
      alert('Please fill all fields');
      return;
    }

    setApproving(true);
    try {
      const site = sites.find((s) => s.id === selectedSite);
      const approveCamera = httpsCallable(functions, 'approveCamera');
      
      await approveCamera({
        deviceId: selectedCamera.deviceId,
        cameraName,
        siteId: selectedSite,
        subadminId: site.subadminId,
      });

      alert('Camera approved successfully!');
      setSelectedCamera(null);
      setCameraName('');
      setSelectedSite('');
    } catch (error) {
      alert('Failed to approve: ' + error.message);
      console.error(error);
    } finally {
      setApproving(false);
    }
  };

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
        <div style={{ fontSize: '1.25rem' }}>Loading...</div>
      </div>
    );
  }

  return (
    <div style={{ minHeight: '100vh', backgroundColor: '#f9fafb', padding: '2rem' }}>
      <h1 style={{ fontSize: '2rem', fontWeight: 'bold', marginBottom: '2rem' }}>
        Pending Camera Approvals
      </h1>

      {cameras.length === 0 ? (
        <div style={{ 
          backgroundColor: 'white', 
          borderRadius: '8px', 
          boxShadow: '0 1px 3px rgba(0,0,0,0.1)', 
          padding: '3rem', 
          textAlign: 'center' 
        }}>
          <Wifi size={64} style={{ margin: '0 auto 1rem', color: '#9ca3af' }} />
          <h3 style={{ fontSize: '1.25rem', fontWeight: '600', marginBottom: '0.5rem' }}>
            No Pending Cameras
          </h3>
          <p style={{ color: '#6b7280' }}>New cameras will appear here when they register</p>
        </div>
      ) : (
        <div style={{ 
          display: 'grid', 
          gap: '1.5rem', 
          gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))' 
        }}>
          {cameras.map((camera) => (
            <div 
              key={camera.id} 
              style={{ 
                backgroundColor: 'white', 
                borderRadius: '8px', 
                boxShadow: '0 4px 6px rgba(0,0,0,0.1)', 
                padding: '1.5rem' 
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', marginBottom: '1rem' }}>
                <div style={{ backgroundColor: '#fef3c7', padding: '0.75rem', borderRadius: '8px' }}>
                  <Wifi size={24} style={{ color: '#d97706' }} />
                </div>
                <div style={{ marginLeft: '0.75rem' }}>
                  <h3 style={{ fontWeight: '600' }}>New Camera</h3>
                  <span style={{ 
                    fontSize: '0.75rem', 
                    backgroundColor: '#fef3c7', 
                    color: '#92400e', 
                    padding: '0.25rem 0.5rem', 
                    borderRadius: '4px' 
                  }}>
                    Pending
                  </span>
                </div>
              </div>

              <div style={{ marginBottom: '1rem', fontSize: '0.875rem' }}>
                <div style={{ marginBottom: '0.75rem' }}>
                  <p style={{ fontSize: '0.75rem', color: '#6b7280', textTransform: 'uppercase', fontWeight: '600' }}>
                    Device ID
                  </p>
                  <p style={{ fontFamily: 'monospace', wordBreak: 'break-all', fontSize: '0.8rem' }}>
                    {camera.deviceId}
                  </p>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem', marginBottom: '0.75rem' }}>
                  <div>
                    <p style={{ fontSize: '0.75rem', color: '#6b7280', textTransform: 'uppercase', fontWeight: '600' }}>MAC</p>
                    <p style={{ fontFamily: 'monospace', fontSize: '0.7rem' }}>{camera.macAddress}</p>
                  </div>
                  <div>
                    <p style={{ fontSize: '0.75rem', color: '#6b7280', textTransform: 'uppercase', fontWeight: '600' }}>IP</p>
                    <p style={{ fontFamily: 'monospace', fontSize: '0.7rem' }}>{camera.ipAddress}</p>
                  </div>
                </div>
                <div>
                  <p style={{ fontSize: '0.75rem', color: '#6b7280', textTransform: 'uppercase', fontWeight: '600' }}>Hardware</p>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginTop: '0.25rem' }}>
                    <Cpu size={16} style={{ color: '#9ca3af' }} />
                    <p style={{ fontSize: '0.8rem' }}>{camera.hardwareInfo?.model || 'Unknown'}</p>
                  </div>
                  {camera.hardwareInfo?.hailo && (
                    <span style={{ 
                      display: 'inline-block', 
                      marginTop: '0.5rem', 
                      padding: '0.25rem 0.5rem', 
                      backgroundColor: '#d1fae5', 
                      color: '#065f46', 
                      fontSize: '0.75rem', 
                      borderRadius: '4px',
                      fontWeight: '600'
                    }}>
                      ✓ Hailo-8 Detected
                    </span>
                  )}
                </div>
              </div>

              <div style={{ display: 'flex', gap: '0.5rem', paddingTop: '1rem', borderTop: '1px solid #e5e7eb' }}>
                <button
                  onClick={() => setSelectedCamera(camera)}
                  style={{ 
                    flex: 1, 
                    display: 'flex', 
                    alignItems: 'center', 
                    justifyContent: 'center', 
                    gap: '0.5rem', 
                    padding: '0.75rem', 
                    backgroundColor: '#10b981', 
                    color: 'white', 
                    border: 'none', 
                    borderRadius: '8px', 
                    cursor: 'pointer',
                    fontSize: '0.875rem',
                    fontWeight: '600'
                  }}
                >
                  <CheckCircle size={16} />
                  Approve
                </button>
                <button
                  onClick={() => handleReject(camera)}
                  style={{ 
                    flex: 1, 
                    display: 'flex', 
                    alignItems: 'center', 
                    justifyContent: 'center', 
                    gap: '0.5rem', 
                    padding: '0.75rem', 
                    backgroundColor: '#ef4444', 
                    color: 'white', 
                    border: 'none', 
                    borderRadius: '8px', 
                    cursor: 'pointer',
                    fontSize: '0.875rem',
                    fontWeight: '600'
                  }}
                >
                  <XCircle size={16} />
                  Reject
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {selectedCamera && (
        <div style={{ 
          position: 'fixed', 
          inset: 0, 
          backgroundColor: 'rgba(0,0,0,0.5)', 
          display: 'flex', 
          alignItems: 'center', 
          justifyContent: 'center',
          zIndex: 1000
        }}>
          <div style={{ 
            backgroundColor: 'white', 
            borderRadius: '12px', 
            boxShadow: '0 20px 25px rgba(0,0,0,0.3)', 
            maxWidth: '600px', 
            width: '90%',
            maxHeight: '90vh',
            overflow: 'auto'
          }}>
            <div style={{ padding: '1.5rem', borderBottom: '1px solid #e5e7eb' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <h2 style={{ fontSize: '1.5rem', fontWeight: 'bold' }}>Approve Camera</h2>
                <button
                  onClick={() => setSelectedCamera(null)}
                  style={{ 
                    padding: '0.5rem', 
                    border: 'none', 
                    background: 'none', 
                    cursor: 'pointer',
                    fontSize: '2rem',
                    lineHeight: 1,
                    color: '#6b7280'
                  }}
                >
                  ×
                </button>
              </div>
            </div>

            <div style={{ padding: '1.5rem' }}>
              <div style={{ 
                backgroundColor: '#f9fafb', 
                borderRadius: '8px', 
                padding: '1rem', 
                marginBottom: '1.5rem' 
              }}>
                <h3 style={{ fontWeight: '600', marginBottom: '0.75rem' }}>Camera Information</h3>
                <div style={{ fontSize: '0.875rem', lineHeight: '1.8' }}>
                  <p><strong>Device ID:</strong> <span style={{ fontFamily: 'monospace', fontSize: '0.75rem' }}>{selectedCamera.deviceId}</span></p>
                  <p><strong>MAC:</strong> {selectedCamera.macAddress}</p>
                  <p><strong>IP:</strong> {selectedCamera.ipAddress}</p>
                  <p><strong>Hardware:</strong> {selectedCamera.hardwareInfo?.model}</p>
                </div>
              </div>

              <div style={{ marginBottom: '1.5rem' }}>
                <label style={{ display: 'block', fontSize: '0.875rem', fontWeight: '600', marginBottom: '0.5rem' }}>
                  Camera Name *
                </label>
                <input
                  type="text"
                  value={cameraName}
                  onChange={(e) => setCameraName(e.target.value)}
                  placeholder="e.g., Entrance Camera 1"
                  style={{ 
                    width: '100%', 
                    padding: '0.75rem', 
                    border: '1px solid #d1d5db', 
                    borderRadius: '8px',
                    fontSize: '1rem'
                  }}
                />
              </div>

              <div style={{ marginBottom: '1.5rem' }}>
                <label style={{ display: 'block', fontSize: '0.875rem', fontWeight: '600', marginBottom: '0.5rem' }}>
                  Assign to Site *
                </label>
                <select
                  value={selectedSite}
                  onChange={(e) => setSelectedSite(e.target.value)}
                  style={{ 
                    width: '100%', 
                    padding: '0.75rem', 
                    border: '1px solid #d1d5db', 
                    borderRadius: '8px',
                    fontSize: '1rem'
                  }}
                >
                  <option value="">Select a site...</option>
                  {sites.map((site) => (
                    <option key={site.id} value={site.id}>
                      {site.name} - {site.location}
                    </option>
                  ))}
                </select>
              </div>

              <div style={{ display: 'flex', gap: '0.75rem', paddingTop: '1rem', borderTop: '1px solid #e5e7eb' }}>
                <button
                  onClick={() => setSelectedCamera(null)}
                  disabled={approving}
                  style={{ 
                    flex: 1, 
                    padding: '0.75rem', 
                    border: '1px solid #d1d5db', 
                    backgroundColor: 'white',
                    borderRadius: '8px', 
                    cursor: 'pointer',
                    fontSize: '1rem',
                    fontWeight: '600'
                  }}
                >
                  Cancel
                </button>
                <button
                  onClick={handleApprove}
                  disabled={approving}
                  style={{ 
                    flex: 1, 
                    padding: '0.75rem', 
                    backgroundColor: '#10b981', 
                    color: 'white', 
                    border: 'none', 
                    borderRadius: '8px', 
                    cursor: 'pointer',
                    fontSize: '1rem',
                    fontWeight: '600',
                    opacity: approving ? 0.6 : 1
                  }}
                >
                  {approving ? 'Approving...' : 'Approve & Activate'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;