"""Regression checks for firmware semantics that do not require PlatformIO."""

from collections import deque
from pathlib import Path


ROOT = Path(__file__).parents[2]
MAIN = (ROOT / "firmware_esp32/src/main.cpp").read_text(encoding="utf-8")
MQTT = (ROOT / "firmware_esp32/src/mqtt_handler.cpp").read_text(encoding="utf-8")
SHARED = (ROOT / "firmware_esp32/src/shared_state.h").read_text(encoding="utf-8")


def test_lru_fail_polarity_is_inverted_at_call_site():
    assert "modbusUpdateLRUFail(!statusMqttTerhubung)" in MAIN
    register_values = [int(not connected) for connected in (True, False, True)]
    assert register_values == [0, 1, 0]


def test_remote_queue_is_bounded_fifo_and_never_overwritten():
    assert "REMOTE_COMMAND_QUEUE_LENGTH = 4" in SHARED
    assert "queuePerintahRemote = xQueueCreate(REMOTE_COMMAND_QUEUE_LENGTH" in MAIN
    assert "xQueueSend(queuePerintahRemote, &nilai, 0)" in MQTT
    assert "xQueueOverwrite(queuePerintahRemote" not in MQTT

    queue = deque(maxlen=4)

    def try_send(command):
        if len(queue) == queue.maxlen:
            return False
        queue.append(command)
        return True

    accepted = [try_send(command) for command in (1, 2, 1, 2)]
    rejected = not try_send(1)
    assert accepted == [True, True, True, True]
    assert rejected
    assert list(queue) == [1, 2, 1, 2]


def test_modbus_command_waits_for_register_ack_before_dequeue():
    receive = "xQueueReceive(queuePerintahRemote, &perintahBaru, 0)"
    assert "modbusSlaveTask();" in MAIN
    assert "if (modbusBacaRegisterCommand() == 0)" in MAIN
    assert MAIN.index("modbusSlaveTask();") < MAIN.index("modbusBacaRegisterCommand()")
    assert MAIN.index("modbusBacaRegisterCommand()") < MAIN.index(receive)
    assert "if (perintahBaru == 1 || perintahBaru == 2)" in MAIN
    assert "modbusTulisPerintahRemote(perintahBaru);" in MAIN

    queue = deque((1, 2))
    holding_register = 0

    def task_step():
        nonlocal holding_register
        if holding_register != 0:
            return None
        if not queue:
            return None
        command = queue.popleft()
        if command in (1, 2):
            holding_register = command
            return command
        return None

    assert task_step() == 1
    assert list(queue) == [2]
    assert task_step() is None
    assert list(queue) == [2]
    holding_register = 0
    assert task_step() == 2
    assert list(queue) == []


if __name__ == "__main__":
    test_lru_fail_polarity_is_inverted_at_call_site()
    test_remote_queue_is_bounded_fifo_and_never_overwritten()
    test_modbus_command_waits_for_register_ack_before_dequeue()
    print("PASS: firmware regression checks")
