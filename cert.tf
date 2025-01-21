# Create ACM certificate
resource "aws_acm_certificate" "cert" {
  count = var.is_enabled_https_public ? 1 : 0
  domain_name       = format("%s.%s", var.public_lb_vpn_domain, var.route53_zone_name)
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge({
    Name = format("%s-cert", local.name),
  }, local.tags)
}

# Create DNS validation record for the certificate
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this[0].id
}

# Wait for certificate validation
resource "aws_acm_certificate_validation" "cert_validation" {
  count = var.is_enabled_https_public ? 1 : 0
  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
