import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from fastapi.testclient import TestClient
from pydantic import ValidationError

from smarthome_api.main import app
from smarthome_api.repositories.room_repository import RoomRepository
from smarthome_api.schemas.room import RoomCreate
from smarthome_api.services import room_service


class RoomApiTests(unittest.TestCase):
    def test_house_rooms_include_the_four_floor_plan_links(self):
        with TestClient(app) as client:
            response = client.get('/api/v1/houses/house-001/rooms')
            self.assertEqual(response.status_code, 200)
            rooms = response.json()
            self.assertEqual(
                [(room['name'], room['floor_plan_object_name']) for room in rooms],
                [('Living Room', 'livingRoom'), ('Kitchen', 'kitchen'),
                 ('Bedroom 1', 'bedroom1'), ('Bathroom 1', 'bathroom1')],
            )
            ids = {room['id'] for room in rooms}
            devices = client.get('/api/v1/houses/house-001/devices').json()
            self.assertTrue(all(device['room_id'] in ids for device in devices
                                if device.get('room_id') is not None))

    def test_create_round_trips_optional_mesh_name_without_changing_real_data(self):
        with tempfile.TemporaryDirectory() as directory:
            repository = RoomRepository()
            repository.file_path = Path(directory) / 'rooms.json'
            repository.file_path.write_text('[]', encoding='utf-8')
            with patch.object(room_service, 'room_repository', repository), TestClient(app) as client:
                for room_id, object_name in [('mapped-room', 'officeMesh'), ('unmapped-room', None)]:
                    body = {'id': room_id, 'name': 'Office'}
                    if object_name is not None:
                        body['floor_plan_object_name'] = object_name
                    response = client.post('/api/v1/houses/house-001/rooms', json=body)
                    self.assertEqual(response.status_code, 201, response.text)
                    self.assertEqual(response.json()['floor_plan_object_name'], object_name)
                    saved = client.get(f'/api/v1/houses/house-001/rooms/{room_id}')
                    self.assertEqual(saved.json()['floor_plan_object_name'], object_name)
            stored = json.loads(repository.file_path.read_text(encoding='utf-8'))
            self.assertEqual(stored[0]['floor_plan_object_name'], 'officeMesh')
            self.assertIsNone(stored[1]['floor_plan_object_name'])

    def test_missing_house_remains_a_404(self):
        with TestClient(app) as client:
            self.assertEqual(client.get('/api/v1/houses/unknown-house/rooms').status_code, 404)

    def test_empty_mesh_name_is_rejected(self):
        with self.assertRaises(ValidationError):
            RoomCreate(id='room', name='Room', floor_plan_object_name='')


if __name__ == '__main__':
    unittest.main()
