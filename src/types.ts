export interface Announcement {
  id: string;
  image_url: string;
  display_duration: number; // in seconds
  transition_type: 'fade' | 'slide' | 'none';
  active: boolean;
  created_at: string;
}

export interface AppSettings {
  id?: number;
  default_duration: number; // in seconds
  refresh_interval: number; // in minutes
}
