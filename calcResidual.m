function F = calcResidual(...
    Net,X,idxP,idxQH,idxQV)

[F,~] = calcResidualJacobian(...
    Net,X,idxP,idxQH,idxQV);

end