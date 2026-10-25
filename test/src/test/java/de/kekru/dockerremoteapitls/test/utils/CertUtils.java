package de.kekru.dockerremoteapitls.test.utils;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.security.cert.CertificateFactory;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Date;
import java.security.cert.X509Certificate;

public class CertUtils {

  private final X509Certificate cert;

  public CertUtils(File file) {
    cert = getCert(file);
  }

  private X509Certificate getCert(File file) {
    try (InputStream in = new FileInputStream(file)) {
      return (X509Certificate) CertificateFactory.getInstance("X.509").generateCertificate(in);
    } catch (Exception e) {
      throw new RuntimeException(e);
    }
  }

  public LocalDate getExpiresAt() {
    return toLocalDate(cert.getNotAfter());
  }

  public LocalDate toLocalDate(Date dateToConvert) {
    return dateToConvert.toInstant()
        .atZone(ZoneId.systemDefault())
        .toLocalDate();
  }

  public X509Certificate getCert() {
    return cert;
  }
}
