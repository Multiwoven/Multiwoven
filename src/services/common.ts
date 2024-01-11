// services/login.ts

import { axiosInstance as axios } from './axios';

interface ApiResponse {
    success: boolean;
    response?: any;
}

const apiRequest = async (url: string, values: any): Promise<ApiResponse> => {
    let data = JSON.stringify(values);
    let response;
    try {
        if (values === null) {
            response = await axios.get(url);
        } else {
            response = await axios.post(url, data);
        }
        return { success: true, response };
    } catch (error) {
        console.error(`API Request Error for ${url}:`, error);
        return { success: false };
    }
};

export const login = async (values: any): Promise<ApiResponse> => {
    return apiRequest('/login', values);
};

export const signUp = async (values: any): Promise<ApiResponse> => {
    return apiRequest('/signup', values);
};

export const accountVerify = async (values: any): Promise<ApiResponse> => {
    return apiRequest('/verify_code', values);
};

export const getAllModels = async (): Promise<ApiResponse> => {
    return apiRequest('/models', null);
};

export const getUserConnectors = async (connectorType: string): Promise<ApiResponse> => {
    return apiRequest("/connectors?type=" + connectorType, null);
};

export const getUserConnector = async (connectorID: string): Promise<ApiResponse> => {
    return apiRequest("/connectors" + connectorID, null);
};

export const getConnectorsDefintions = async (connectorType: string): Promise<ApiResponse> => {
    return apiRequest("/connector_definitions?type=" + connectorType, null);
};

export const getConnectorDefintion = async (connectorType: string,
	connectorName: string): Promise<ApiResponse> => {
    return apiRequest("/connector_definitions/" + connectorName + "?type=" + connectorType, null);
};

export const getConnectorData = async (connectorID: string): Promise<ApiResponse> => {
    return apiRequest("/connectors/" + connectorID, null);
};
