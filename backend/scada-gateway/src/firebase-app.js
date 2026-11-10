import { applicationDefault } from 'firebase-admin/app';

export const GATEWAY_UID = 'scada-lbs-gateway';
export const GATEWAY_APP_NAME = GATEWAY_UID;

export function gatewayAppOptions(databaseUrl) {
  return {
    credential: applicationDefault(),
    databaseURL: databaseUrl,
    databaseAuthVariableOverride: {
      uid: GATEWAY_UID,
    },
  };
}