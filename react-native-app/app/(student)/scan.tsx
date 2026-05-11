import React, { useState } from 'react';
import { StyleSheet, Text, View, TouchableOpacity, Alert } from 'react-native';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { useRouter } from 'expo-router';
import { attendanceAPI } from '@/services/api';
import { useStore } from '@/store/useStore';

export default function QRScannerScreen() {
  const [permission, requestPermission] = useCameraPermissions();
  const [scanned, setScanned] = useState(false);
  const router = useRouter();
  const { studentId } = useStore();

  if (!permission) {
    return <View />;
  }

  if (!permission.granted) {
    return (
      <View style={styles.container}>
        <Text style={{ textAlign: 'center', marginBottom: 20 }}>We need your permission to show the camera</Text>
        <TouchableOpacity onPress={requestPermission} style={styles.button}>
          <Text style={styles.buttonText}>Grant Permission</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const handleBarCodeScanned = async ({ data }: { data: string }) => {
    if (scanned) return;
    setScanned(true);

    // Expected data format: "checkin:LECTURE_ID"
    if (data.startsWith('checkin:')) {
      const lectureId = data.split(':')[1];
      try {
        await attendanceAPI.scanCheckIn(lectureId, studentId || '');
        Alert.alert('Success', 'Attendance marked for ' + lectureId, [
          { text: 'OK', onPress: () => router.back() }
        ]);
      } catch (error: any) {
        Alert.alert('Error', error.response?.data?.detail || 'Failed to check in');
        setScanned(false);
      }
    } else {
      Alert.alert('Invalid QR', 'This is not a valid AAST attendance code.');
      setScanned(false);
    }
  };

  return (
    <View style={styles.container}>
      <CameraView
        style={StyleSheet.absoluteFillObject}
        onBarcodeScanned={scanned ? undefined : handleBarCodeScanned}
        barcodeScannerSettings={{
          barcodeTypes: ['qr'],
        }}
      />
      <View style={styles.overlay}>
        <View style={styles.unfocusedContainer}></View>
        <View style={styles.focusedContainer}>
           <View style={styles.cornerTopLeft} />
           <View style={styles.cornerTopRight} />
           <View style={styles.cornerBottomLeft} />
           <View style={styles.cornerBottomRight} />
        </View>
        <View style={styles.unfocusedContainer}>
           <Text style={styles.hintText}>Scan the Classroom QR Code</Text>
        </View>
      </View>
      {scanned && (
        <TouchableOpacity onPress={() => setScanned(false)} style={styles.rescanButton}>
          <Text style={styles.buttonText}>Tap to Scan Again</Text>
        </TouchableOpacity>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    flexDirection: 'column',
    justifyContent: 'center',
    backgroundColor: '#000',
  },
  overlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
  },
  unfocusedContainer: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  focusedContainer: {
    width: 250,
    height: 250,
    alignSelf: 'center',
  },
  cornerTopLeft: { position: 'absolute', top: 0, left: 0, width: 40, height: 40, borderTopWidth: 5, borderLeftWidth: 5, borderColor: '#C9A84C' },
  cornerTopRight: { position: 'absolute', top: 0, right: 0, width: 40, height: 40, borderTopWidth: 5, borderRightWidth: 5, borderColor: '#C9A84C' },
  cornerBottomLeft: { position: 'absolute', bottom: 0, left: 0, width: 40, height: 40, borderBottomWidth: 5, borderLeftWidth: 5, borderColor: '#C9A84C' },
  cornerBottomRight: { position: 'absolute', bottom: 0, right: 0, width: 40, height: 40, borderBottomWidth: 5, borderRightWidth: 5, borderColor: '#C9A84C' },
  button: {
    backgroundColor: '#002147',
    padding: 15,
    borderRadius: 8,
    alignSelf: 'center',
  },
  rescanButton: {
    position: 'absolute',
    bottom: 50,
    backgroundColor: '#C9A84C',
    padding: 15,
    borderRadius: 8,
    alignSelf: 'center',
  },
  buttonText: { color: 'white', fontWeight: 'bold' },
  hintText: { color: 'white', fontSize: 18, marginTop: 20, fontWeight: '500' }
});
