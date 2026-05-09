import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, FlatList, ActivityIndicator } from 'react-native';
import { supabase } from '@/services/supabase';
import { useStore } from '@/store/useStore';

export default function ScheduleView() {
  const { studentId } = useStore();
  const [schedule, setSchedule] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchSchedule();
  }, []);

  const fetchSchedule = async () => {
    setLoading(true);
    // Join query: Enrollments -> Classes -> ClassSchedule -> Courses
    const { data, error } = await supabase
      .from('enrollments')
      .select(`
        classes(
          class_id,
          class_schedule(
            day_of_week,
            start_time,
            end_time
          ),
          courses(
            title
          )
        )
      `)
      .eq('student_id', studentId);

    if (error) {
      console.error('Error fetching schedule:', error);
    } else if (data) {
      // Flatten data
      const flat = data.map(item => ({
        course: item.classes?.courses?.title,
        schedule: item.classes?.class_schedule
      })).filter(i => i.course);
      setSchedule(flat);
    }
    setLoading(false);
  };

  if (loading) return <ActivityIndicator style={styles.center} />;

  return (
    <View style={styles.container}>
      <Text style={styles.header}>Your Schedule</Text>
      <FlatList
        data={schedule}
        keyExtractor={(_, index) => index.toString()}
        renderItem={({ item }) => (
          <View style={styles.item}>
            <Text style={styles.course}>{item.course}</Text>
            {item.schedule && item.schedule.map((s: any, idx: number) => (
                <Text key={idx}>{s.day_of_week}: {s.start_time} - {s.end_time}</Text>
            ))}
          </View>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  center: { flex: 1, justifyContent: 'center' },
  header: { fontSize: 20, fontWeight: 'bold', marginBottom: 12 },
  item: { backgroundColor: '#fff', padding: 16, borderRadius: 8, marginBottom: 8 },
  course: { fontSize: 16, fontWeight: '600' }
});
