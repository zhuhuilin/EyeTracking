"""
SQLite database management for tracking sessions and results.
"""
import sqlite3
import json
from datetime import datetime
from pathlib import Path
from typing import List, Optional, Dict, Any
import config

class Database:
    """Manages SQLite database operations for eye tracking data."""

    def __init__(self, db_path: Path = config.DATABASE_PATH):
        self.db_path = db_path
        self.connection: Optional[sqlite3.Connection] = None

    def connect(self):
        """Establish database connection and create tables if needed."""
        self.connection = sqlite3.connect(
            self.db_path,
            timeout=config.DB_TIMEOUT,
            check_same_thread=False
        )
        self.connection.row_factory = sqlite3.Row
        self._create_tables()

    def disconnect(self):
        """Close database connection."""
        if self.connection:
            self.connection.close()
            self.connection = None

    def _create_tables(self):
        """Create database schema."""
        cursor = self.connection.cursor()

        # Users table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                email TEXT UNIQUE NOT NULL,
                role TEXT NOT NULL DEFAULT 'user',
                created_at TEXT NOT NULL
            )
        """)

        # Test sessions table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS test_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                test_type TEXT NOT NULL,
                duration INTEGER NOT NULL,
                circle_size INTEGER,
                movement_speed INTEGER,
                started_at TEXT NOT NULL,
                completed_at TEXT,
                results_json TEXT,
                FOREIGN KEY (user_id) REFERENCES users(id)
            )
        """)

        # Tracking data points table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS tracking_data (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id INTEGER NOT NULL,
                timestamp TEXT NOT NULL,
                face_distance REAL,
                gaze_angle_x REAL,
                gaze_angle_y REAL,
                eyes_focused INTEGER,
                head_moving INTEGER,
                shoulders_moving INTEGER,
                face_detected INTEGER,
                target_x REAL,
                target_y REAL,
                FOREIGN KEY (session_id) REFERENCES test_sessions(id)
            )
        """)

        # Calibration data table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS calibration_data (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                calibrated_at TEXT NOT NULL,
                calibration_points_json TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(id)
            )
        """)

        self.connection.commit()

    def create_user(self, email: str, role: str = "user") -> int:
        """Create a new user and return user ID."""
        cursor = self.connection.cursor()
        cursor.execute(
            "INSERT INTO users (email, role, created_at) VALUES (?, ?, ?)",
            (email, role, datetime.now().isoformat())
        )
        self.connection.commit()
        return cursor.lastrowid

    def get_user(self, email: str) -> Optional[Dict[str, Any]]:
        """Get user by email."""
        cursor = self.connection.cursor()
        cursor.execute("SELECT * FROM users WHERE email = ?", (email,))
        row = cursor.fetchone()
        return dict(row) if row else None

    def create_test_session(self, user_id: int, test_type: str,
                           duration: int, circle_size: int = None,
                           movement_speed: int = None) -> int:
        """Create a new test session and return session ID."""
        cursor = self.connection.cursor()
        cursor.execute(
            """INSERT INTO test_sessions
               (user_id, test_type, duration, circle_size, movement_speed, started_at)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (user_id, test_type, duration, circle_size, movement_speed,
             datetime.now().isoformat())
        )
        self.connection.commit()
        return cursor.lastrowid

    def complete_test_session(self, session_id: int, results: Dict[str, Any]):
        """Mark test session as completed with results."""
        cursor = self.connection.cursor()
        cursor.execute(
            """UPDATE test_sessions
               SET completed_at = ?, results_json = ?
               WHERE id = ?""",
            (datetime.now().isoformat(), json.dumps(results), session_id)
        )
        self.connection.commit()

    def add_tracking_data(self, session_id: int, tracking_result: Dict[str, Any],
                         target_x: float = None, target_y: float = None):
        """Add a tracking data point to a session."""
        cursor = self.connection.cursor()
        cursor.execute(
            """INSERT INTO tracking_data
               (session_id, timestamp, face_distance, gaze_angle_x, gaze_angle_y,
                eyes_focused, head_moving, shoulders_moving, face_detected,
                target_x, target_y)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                session_id,
                datetime.now().isoformat(),
                tracking_result.get("face_distance"),
                tracking_result.get("gaze_angle_x"),
                tracking_result.get("gaze_angle_y"),
                int(tracking_result.get("eyes_focused", False)),
                int(tracking_result.get("head_moving", False)),
                int(tracking_result.get("shoulders_moving", False)),
                int(tracking_result.get("face_detected", False)),
                target_x,
                target_y
            )
        )
        self.connection.commit()

    def get_user_sessions(self, user_id: int) -> List[Dict[str, Any]]:
        """Get all test sessions for a user."""
        cursor = self.connection.cursor()
        cursor.execute(
            "SELECT * FROM test_sessions WHERE user_id = ? ORDER BY started_at DESC",
            (user_id,)
        )
        return [dict(row) for row in cursor.fetchall()]

    def get_session_data(self, session_id: int) -> List[Dict[str, Any]]:
        """Get all tracking data points for a session."""
        cursor = self.connection.cursor()
        cursor.execute(
            "SELECT * FROM tracking_data WHERE session_id = ? ORDER BY timestamp",
            (session_id,)
        )
        return [dict(row) for row in cursor.fetchall()]
