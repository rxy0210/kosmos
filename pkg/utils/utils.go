package utils

import (
	"context"
	"fmt"
	"strings"

	authenticationv1 "k8s.io/api/authentication/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

func ContainsString(arr []string, s string) bool {
	for _, str := range arr {
		if strings.Contains(str, s) {
			return true
		}
	}
	return false
}

func IsIPv6(s string) bool {
	// 0.234.63.0 and 0.234.63.0/22
	for i := 0; i < len(s); i++ {
		switch s[i] {
		case '.':
			return false
		case ':':
			return true
		}
	}
	return false
}

func CreateToken(clientset kubernetes.Interface, namespaceName string, serviceAccountName string, ExpirationSeconds *int64, BoundObjectReference *authenticationv1.BoundObjectReference) (*authenticationv1.TokenRequest, error) {
	tokenRequest, err := clientset.CoreV1().ServiceAccounts(namespaceName).CreateToken(context.TODO(), serviceAccountName, &authenticationv1.TokenRequest{
		Spec: authenticationv1.TokenRequestSpec{
			Audiences:         []string{"https://kubernetes.default.svc.cluster.local"},
			ExpirationSeconds: ExpirationSeconds,
			BoundObjectRef:    BoundObjectReference,
		},
	}, metav1.CreateOptions{})
	if err != nil {
		return nil, fmt.Errorf("could not create token by serviceAccountName %s in Namespace %s: %v", serviceAccountName, namespaceName, err)
	}
	return tokenRequest, nil

}
